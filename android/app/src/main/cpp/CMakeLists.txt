cmake_minimum_required(VERSION 3.22.1)
project("repp_qwen3_tts" C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure compiler flags for ARM64 NEON optimization
if(${ANDROID_ABI} STREQUAL "arm64-v8a")
    add_compile_options(-O3 -fPIC -DANDROID -D__ARM_NEON)
endif()

# Dummy stub JNI source until external qwen3-tts.cpp submodule / shared objects are linked
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/repp_qwen3_tts_stub.cpp
"#include <jni.h>
#include <string>

extern \"C\" JNIEXPORT jlong JNICALL
Java_com_repp_repp_QwenTtsBridge_nativeInit(JNIEnv* env, jobject thiz, jstring tokenizer_path, jstring talker_path) {
    return 1L;
}

extern \"C\" JNIEXPORT jbyteArray JNICALL
Java_com_repp_repp_QwenTtsBridge_nativeSynthesize(JNIEnv* env, jobject thiz, jstring text, jstring voice_prompt) {
    return nullptr;
}

extern \"C\" JNIEXPORT void JNICALL
Java_com_repp_repp_QwenTtsBridge_nativeStop(JNIEnv* env, jobject thiz) {
}
")

add_library(repp_qwen3_tts SHARED
    ${CMAKE_CURRENT_BINARY_DIR}/repp_qwen3_tts_stub.cpp
)

# Enforce 16 KB ELF segment alignment for Android 15+ compatibility
target_link_options(repp_qwen3_tts PRIVATE "-Wl,-z,max-page-size=16384")

target_link_libraries(repp_qwen3_tts
    log
)
