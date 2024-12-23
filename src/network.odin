#+vet unused shadowing using-stmt style semicolon
package main

import "core:encoding/json"
import "core:mem"
import "core:net"


send_package :: proc(socket: net.TCP_Socket, msg: $T) {
	buf, json_err := json.marshal(msg)

	assert(json_err == nil, format(json_err))

	size: u64 = transmute(u64)len(buf)
	size_bytes := mem.byte_slice(&size, 8)

	sent_bytes: int
	tcp_err: net.Network_Error

	sent_bytes, tcp_err = net.send_tcp(socket, size_bytes)
	assert(tcp_err == nil, format(tcp_err))
	assert(sent_bytes == 8, format(sent_bytes))

	sent_bytes, tcp_err = net.send_tcp(socket, buf)
	assert(tcp_err == nil, format(tcp_err))
	assert(sent_bytes == int(size), format(sent_bytes))

	print("Sent", string(buf))
}

recv_package :: proc(socket: net.TCP_Socket, msg: $T) -> bool {
	size_bytes: [8]u8
	size_bytes_read, recv_size_err := net.recv_tcp(socket, size_bytes[:])

	(size_bytes_read != 0) or_return

	(recv_size_err == nil && size_bytes_read == 8) or_return

	size := int(transmute(u64)(size_bytes))

	buf := make([]u8, size)
	defer delete(buf)
	msg_bytes_read, recv_buf_error := net.recv_tcp(socket, buf)

	(recv_buf_error == nil && msg_bytes_read == size) or_return

	json.unmarshal(buf, msg)

	print("Recv'd!")

	return true
}
