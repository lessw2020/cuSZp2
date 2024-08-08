# Find CUDA package
find_package(CUDA REQUIRED)

set(install_dir ${PROJECT_BINARY_DIR}/examples/bin)
set(execName_gpu_p "gsz_p")
set(execName_gpu_o "gsz_o") # CPU API is not under maintained.
set(SRC_DIR ${PROJECT_SOURCE_DIR}/src)
set(INCLUDE_DIR ${PROJECT_SOURCE_DIR}/include)

# Add include and library directories
include_directories(${INCLUDE_DIR})

# Compile headers as a library
cuda_add_library(GSZ_example STATIC ${SRC_DIR}/GSZ.cu
                                    ${SRC_DIR}/GSZ_utility.cu
                                    ${SRC_DIR}/GSZ_timer.cu
                                    ${SRC_DIR}/GSZ_entry.cu)

# Compile executable binary
cuda_add_executable(${execName_gpu_p} gsz_p.cpp)
cuda_add_executable(${execName_gpu_o} gsz_o.cpp)

# Link with headers
target_link_libraries(${execName_gpu_p} GSZ_example)
target_link_libraries(${execName_gpu_o} GSZ_example)

# Set output paths for the compiled binary
set_target_properties(${execName_gpu_p} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${install_dir})
set_target_properties(${execName_gpu_o} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${install_dir})

# Set installation paths for the compiled binary.
install(TARGETS ${execName_gpu_p} DESTINATION bin)
install(TARGETS ${execName_gpu_o} DESTINATION bin)