// ignore_for_file: implementation_imports
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

/// float16 <-> float32 bit conversion (IEEE 754, round-to-nearest-even).
/// Pure logic — unit-tested. The `onnxruntime` plugin cannot move fp16
/// tensors, so S1's fp16 KV cache crosses this bridge.
int floatToFp16Bits(double value) {
  final f32 = ByteData(4)..setFloat32(0, value, Endian.little);
  final bits = f32.getUint32(0, Endian.little);
  final sign = (bits >> 16) & 0x8000;
  final exp = ((bits >> 23) & 0xFF) - 112;
  final mantissa = bits & 0x7FFFFF;
  if (exp <= 0) {
    if (exp < -10) return sign; // underflow -> signed zero
    final shifted = (mantissa | 0x800000) >> (1 - exp);
    return sign | ((shifted + 0xFFF) >> 13);
  }
  if (exp >= 31) return sign | 0x7BFF; // overflow -> max finite (no inf)
  return sign | (exp << 10) | (mantissa >> 13);
}

double fp16BitsToFloat32(int bits) {
  final sign = (bits & 0x8000) << 16;
  final exp = (bits >> 10) & 0x1F;
  final mantissa = bits & 0x3FF;
  int f32;
  if (exp == 0) {
    if (mantissa == 0) {
      f32 = sign;
    } else {
      var e = -14;
      var m = mantissa;
      while ((m & 0x400) == 0) {
        m <<= 1;
        e--;
      }
      m &= 0x3FF;
      f32 = sign | ((e + 127) << 23) | (m << 13);
    }
  } else if (exp == 31) {
    f32 = sign | 0x7F800000 | (mantissa << 13);
  } else {
    f32 = sign | ((exp + 112) << 23) | (mantissa << 13);
  }
  return (ByteData(4)..setUint32(0, f32, Endian.little))
      .getFloat32(0, Endian.little);
}

/// Runtime IO layout of the S1 decoder export, discovered from session
/// input/output names (no hardcoded names — the export may rename).
class S1IoLayout {
  final String logitsOutput;
  final List<String> pastInputs; // aligned 1:1 with [presentOutputs]
  final List<String> presentOutputs;
  final String? maskInput;
  final String inputIdsName;

  const S1IoLayout({
    required this.logitsOutput,
    required this.pastInputs,
    required this.presentOutputs,
    required this.maskInput,
    required this.inputIdsName,
  });

  /// Pure classifier — unit-tested.
  static S1IoLayout? classify(List<String> inputs, List<String> outputs) {
    String? inputIds;
    for (final n in inputs) {
      if (n == 'input_ids') {
        inputIds = n;
        break;
      }
    }
    if (inputIds == null) return null;

    String? mask;
    for (final n in inputs) {
      final lower = n.toLowerCase();
      if (lower.contains('mask')) {
        mask = n;
        break;
      }
    }

    final past = inputs
        .where((n) => n != inputIds && n != mask)
        .toList()
      ..sort();
    if (past.isEmpty) return null;

    String? logits;
    final present = <String>[];
    for (final n in outputs) {
      final lower = n.toLowerCase();
      if (lower.contains('logit')) {
        logits ??= n;
      } else {
        present.add(n);
      }
    }
    present.sort();
    if (logits == null || present.isEmpty) return null;
    if (past.length != present.length) return null;

    return S1IoLayout(
      logitsOutput: logits,
      pastInputs: past,
      presentOutputs: present,
      maskInput: mask,
      inputIdsName: inputIds,
    );
  }
}

/// Creates an fp16 tensor OrtValue from float32 data (plugin API lacks fp16).
OrtValueTensor createFp16Tensor(Float32List data, List<int> shape) {
  var count = 1;
  for (final d in shape) {
    count *= d;
  }
  if (data.length != count) {
    throw ArgumentError(
      'fp16 data length ${data.length} != shape $shape ($count)',
    );
  }
  final u16 = calloc<ffi.Uint16>(count);
  for (var i = 0; i < count; i++) {
    u16[i] = floatToFp16Bits(data[i]);
  }
  final api = OrtEnv.instance.ortApiPtr.ref;
  final shapePtr = calloc<ffi.Int64>(shape.length)
    ..asTypedList(shape.length).setRange(0, shape.length, shape);
  final memInfoPtrPtr = calloc<ffi.Pointer<bg.OrtMemoryInfo>>();
  var status = api.AllocatorGetInfo.asFunction<
      bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtAllocator>,
          ffi.Pointer<ffi.Pointer<bg.OrtMemoryInfo>>)>()(
    OrtAllocator.instance.ptr,
    memInfoPtrPtr,
  );
  OrtStatus.checkOrtStatus(status);
  final outPtrPtr = calloc<ffi.Pointer<bg.OrtValue>>();
  status = api.CreateTensorWithDataAsOrtValue.asFunction<
      bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtMemoryInfo>,
          ffi.Pointer<ffi.Void>,
          int,
          ffi.Pointer<ffi.Int64>,
          int,
          int,
          ffi.Pointer<ffi.Pointer<bg.OrtValue>>)>()(
    memInfoPtrPtr.value,
    u16.cast(),
    count * 2,
    shapePtr,
    shape.length,
    bg.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16,
    outPtrPtr,
  );
  OrtStatus.checkOrtStatus(status);
  final out = outPtrPtr.value;
  calloc.free(shapePtr);
  calloc.free(memInfoPtrPtr);
  calloc.free(outPtrPtr);
  // NOTE: u16 buffer ownership moves with the OrtValue; freed by release().
  return OrtValueTensor(out, u16.cast<ffi.Void>());
}

/// Reads an fp16 tensor OrtValue into float32 (plugin API lacks fp16).
Float32List readFp16Tensor(OrtValueTensor tensor) {
  final api = OrtEnv.instance.ortApiPtr.ref;
  final infoPtrPtr = calloc<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>();
  var status = api.GetTensorTypeAndShape.asFunction<
      bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtValue>,
          ffi.Pointer<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>)>()(
    tensor.ptr,
    infoPtrPtr,
  );
  OrtStatus.checkOrtStatus(status);
  final infoPtr = infoPtrPtr.value;
  calloc.free(infoPtrPtr);

  final countPtr = calloc<ffi.Size>();
  status = api.GetTensorShapeElementCount.asFunction<
      bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>,
          ffi.Pointer<ffi.Size>)>()(
    infoPtr,
    countPtr,
  );
  OrtStatus.checkOrtStatus(status);
  final count = countPtr.value;
  calloc.free(countPtr);
  api.ReleaseTensorTypeAndShapeInfo.asFunction<
      void Function(ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>)>()(infoPtr);

  final dataPtrPtr = calloc<ffi.Pointer<ffi.Void>>();
  status = api.GetTensorMutableData.asFunction<
      bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtValue>,
          ffi.Pointer<ffi.Pointer<ffi.Void>>)>()(
    tensor.ptr,
    dataPtrPtr,
  );
  OrtStatus.checkOrtStatus(status);
  final u16 = dataPtrPtr.value.cast<ffi.Uint16>().asTypedList(count);
  final out = Float32List(count);
  for (var i = 0; i < count; i++) {
    out[i] = fp16BitsToFloat32(u16[i]);
  }
  calloc.free(dataPtrPtr);
  return out;
}
