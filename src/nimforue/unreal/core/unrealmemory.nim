

#	static FORCEINLINE int32 Memcmp( const void* Buf1, const void* Buf2, SIZE_T Count )


#static FORCEINLINE void* Memcpy(void* Dest, const void* Src, SIZE_T Count)


proc uememcpy*(dest, src : pointer, count : int32) : pointer {. importcpp:"FMemory::Memcpy(@)" .}
#void* FMemory::Malloc(SIZE_T Count, uint32 Alignment)
proc uemalloc*(count : int32, alignment : uint32 = 0) : pointer {. importcpp:"FMemory::Malloc(@)" .}