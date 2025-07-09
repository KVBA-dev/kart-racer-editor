package main

import "core:fmt"
import st "core:strings"

StringBuffer :: struct {
	builder:           st.Builder,
	current_substring: string,
}

init_string_buffer :: proc(buf: ^StringBuffer, cap := 20000) {
	st.builder_init(&buf.builder, cap)
	buf.current_substring = ""
}

delete_string_buffer :: proc(buf: ^StringBuffer) {
	st.builder_destroy(&buf.builder)
	buf.current_substring = ""
}

reset_string_buffer :: proc(buf: ^StringBuffer) {
	st.builder_reset(&buf.builder)
	buf.current_substring = ""
}

append_string_buffer :: proc(buf: ^StringBuffer, str: string) {
	curr_len := st.builder_len(buf.builder)
	fmt.sbprint(&buf.builder, str)
	buf.current_substring = string(buf.builder.buf[curr_len:])
}
