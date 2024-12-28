module main

import crypto.sha256
import db.mysql
import io
import net
import os
import rand
import time

const motd_file = './motd'

const satmud_db_user = 'root'
const satmud_db_name = 'satmud'
const satmud_db_password = 'd0-s56'
const satmud_db_host = '10.0.5.16'
const satmud_db_port = 32768

struct User {
	uid          int
	userid       string
	username     string
	password     string
	email        string
	created      i64
	/* access management settings */
	is_admin     int
	is_liaison   int
	is_tester    int
	is_blocked   int
}

struct Session {
	user User
	ipv4 net.Ip
}

fn main() {
	mut server := net.listen_tcp(.ip, ':12345')!
	laddr := server.addr()!
	eprintln('Listen on ${laddr} ...')
	for {
		mut socket := server.accept()!
		spawn handle_client(mut socket)
	}
}
/*
connection details for local database
10.0.5.16:32768
root
d0-s56
satmud
*/

fn generate_first_user() User {
	uuid := rand.uuid_v4()
	now := time.now()
	usr := User{
		userid: uuid
		username: 'sarmonsiill'
		password: sha256.hexhash('pass123')
		email: 'sarmonsiill@tilde.guru'
		is_admin: 1
	}

	return usr
}


fn handle_client(mut socket net.TcpConn) {

	f := generate_first_user()

	// Create connection
	mut config := mysql.Config{
		username : satmud_db_user
		password : satmud_db_password
		dbname   : satmud_db_name
		host     : satmud_db_host
		port     : satmud_db_port
	}
	// Connect to server
	mut connection := mysql.connect(config) or {
		panic(err)
	}

	//ins := connection.query('INSERT INTO `users` (userid, username, password, email, is_admin) VALUES("${f.userid}", "${f.username}", "${f.password}", "${f.email}", ${f.is_admin})') or {
		//panic(err)
	//}

	// Do a query
	get_users_query_result := connection.query('SELECT * FROM users') or {
		eprintln('query failed: ${err}')
		return
	}
	// Get the result as maps
	for user in get_users_query_result.maps() {
		// Access the name of user
		println(user['username'])
	}

	motd := os.read_file(motd_file) or {
		eprintln('could not read motd file: ${err}')
		exit(1)
	}
	defer {
		connection.close()
		socket.close() or { panic(err) }
	}
	client_addr := socket.peer_addr() or { return }
	eprintln('> new client: ${client_addr}')
	mut reader := io.new_buffered_reader(reader: socket)
	defer {
		unsafe {
			reader.free()
		}
	}

	/* greeting new user with motd */
	socket.write_string('${motd}\n') or { return }

	/* asking for create user or login */
	/* TODO: implement creating an account */
	socket.write_string('username: ') or { return }


	for {
		received_line := reader.read_line() or { return }
		if received_line == '' {
			return
		}
		output := handle_command(mut socket, received_line)

		if output != '' {
			socket.write_string(output) or { return }
		}
	}
}

fn handle_command(mut socket net.TcpConn, raw_input string) string {
	input := raw_input.trim_space()

	match input {
		'exit' { return term(mut socket) }
		else { return '' }
	}

	return ''
}

fn term(mut socket net.TcpConn) string {
	socket.write_string('Bye bye, welcome back soon!\n') or { return '' }
	socket.close() or { panic(err) }
	return 'TERM'
}
