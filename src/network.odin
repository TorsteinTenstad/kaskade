#+vet unused shadowing using-stmt style semicolon
package main

import "core:encoding/json"
import "core:mem"
import "core:net"

send_package :: proc(socket: net.TCP_Socket, msg: $T) -> bool {
	buf, json_err := json.marshal(msg)
	if json_err != nil {
		log_red(json_err, ":", msg)
		return false
	}

	size: u64 = transmute(u64)len(buf)
	size_bytes := mem.byte_slice(&size, 8)

	sent_bytes: int
	tcp_err: net.Network_Error

	sent_bytes, tcp_err = net.send_tcp(socket, size_bytes)
	if tcp_err != nil {
		log_red(tcp_err)
		return false
	}
	if sent_bytes != 8 {
		log_red("Expected to send", 8, "bytes. Sent", sent_bytes)
		return false
	}

	sent_bytes, tcp_err = net.send_tcp(socket, buf)
	if tcp_err != nil {
		log_red(tcp_err)
		return false
	}
	if u64(sent_bytes) != size {
		log_red("Expected to send", size, "bytes. Sent", sent_bytes)
		return false
	}

	log_blue(string(buf))
	return true
}

recv_package :: proc(socket: net.TCP_Socket, msg: $T) -> bool {
	size_bytes: [8]u8
	size_bytes_read, recv_size_err := net.recv_tcp(socket, size_bytes[:])

	(size_bytes_read != 0) or_return

	if recv_size_err != nil {
		log_red(recv_size_err)
		return false
	}

	if size_bytes_read != 8 {
		log_red("Expected to receive", 8, "bytes. Received", size_bytes_read)
		return false
	}

	size := int(transmute(u64)(size_bytes))

	buf := make([]u8, size)
	defer delete(buf)
	msg_bytes_read, recv_buf_error := net.recv_tcp(socket, buf)

	if recv_buf_error != nil {
		log_red(recv_buf_error)
		return false
	}

	if (msg_bytes_read != size) {
		log_red("Expected to receive", size, "bytes. Received", msg_bytes_read)
		return false
	}

	unmarshal_err := json.unmarshal(buf, msg)
	if unmarshal_err != nil {
		log_red(unmarshal_err, "when unmarshaling", string(buf))
		return false
	}

	log_green(string(buf))

	return true
}
