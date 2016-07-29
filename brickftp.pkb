CREATE OR REPLACE
PACKAGE BODY pub.brickftp
IS
	l_credentials	credentials_t;
	l_debug	 BOOLEAN;

	PROCEDURE p( i_str IN VARCHAR2 )
	IS
	BEGIN
		IF ( l_debug ) THEN DBMS_OUTPUT.PUT_LINE( i_str ); END IF;
	END;

	FUNCTION api( i_method IN VARCHAR2, i_service IN VARCHAR2, i_keys IN VARCHAR2_TBL, i_values IN VARCHAR2_TBL )
	RETURN json
	IS
		l_http_request 		UTL_HTTP.req;
		l_http_response		UTL_HTTP.resp;
		l_json						json;
		l_message					VARCHAR2( 1000 );
		m_response				VARCHAR2( 1000 );
		m_url							VARCHAR2( 100 ) := 'https://lifesouth.brickftp.com/api/rest/v1';
	BEGIN
		l_json := json();
		FOR i IN i_keys.first .. i_keys.last
		LOOP
			l_json.put( i_keys( i ), i_values( i ) );
		END LOOP;
		l_message := l_json.to_char();
		p( l_message );

		l_http_request := UTL_HTTP.begin_request(
			url => m_url || i_service,
			method => i_method,
			http_version => 'HTTP/1.1');

		p( i_method || '  ' || m_url || i_service );

		UTL_HTTP.set_header( l_http_request, 'Accept', 'application/json' );
		UTL_HTTP.set_header( l_http_request, 'Content-Type', 'application/json' );

		IF LENGTH( l_message ) > 0 THEN
			UTL_HTTP.set_header( l_http_request, 'Content-Length', LENGTH( l_message ) );
		END IF;
		IF l_credentials.id IS NOT NULL THEN
			UTL_HTTP.set_header( l_http_request, 'Cookie', 'BrickAPI=' || l_credentials.id );
			p( 'BrickAPI=' || l_credentials.id );
		END IF;

		UTL_HTTP.write_text( l_http_request, l_message );

		l_http_response := UTL_HTTP.get_response( l_http_request );
		p( 'Response> status_code: "' || l_http_response.status_code || '"' );
		p( 'Response> reason_phrase: "' || l_http_response.reason_phrase || '"' );
		p( 'Response> http_version: "' || l_http_response.http_version || '"' );
		IF TRUNC( l_http_response.status_code / 100 ) != 2 THEN
			raise_application_error( -20001, 'BrickAPI failed, code=' || l_http_response.status_code || ', reason=' || l_http_response.reason_phrase );
		END IF;

		utl_http.read_text( l_http_response, m_response );

		p( m_response );

		UTL_HTTP.end_response( l_http_response );

		RETURN json( m_response );
	EXCEPTION
		WHEN others THEN
			UTL_HTTP.end_response(l_http_response);
		RAISE;
	END;


	PROCEDURE flush( i_upload IN OUT NOCOPY upload_t )
	IS
		l_http_request 		UTL_HTTP.req;
		l_http_response		UTL_HTTP.resp;
		m_response 				json;
		m_len 						NUMBER;
	BEGIN
		m_len := LENGTH( i_upload.m_clob );
		IF m_len > 0 THEN
			l_http_request := UTL_HTTP.begin_request(
				url => i_upload.uri,
				method => i_upload.http_method,
				http_version => 'HTTP/1.1');

			UTL_HTTP.set_header( l_http_request, 'Content-Length', m_len );
			FOR r IN 1 .. TRUNC(( m_len - 1 )/2000 ) + 1 LOOP
				UTL_HTTP.write_text( l_http_request, DBMS_LOB.SUBSTR( i_upload.m_clob, 2000, (r-1)*2000 + 1 ) );
--					DBMS_OUTPUT.PUT_LINE( DBMS_LOB.SUBSTR( i_upload.m_clob, 2000, (r-1)*2000 + 1 ) );
			END LOOP;

			l_http_response := UTL_HTTP.get_response( l_http_request );
			UTL_HTTP.end_response( l_http_response );
		END IF;
	EXCEPTION
		WHEN others THEN
			UTL_HTTP.end_response(l_http_response);
			RAISE;
	END;

	---------------------------------------------------------------------------
	/*
	 */
	---------------------------------------------------------------------------

	PROCEDURE debug
	IS
	BEGIN
		l_debug := true;
	END;

	---------------------------------------------------------------------------
	/*
	 */
	---------------------------------------------------------------------------

	PROCEDURE init( i_wallet IN VARCHAR2, i_username IN VARCHAR2, i_password IN VARCHAR2 )
	IS
		m_response json;
		m_keys		VARCHAR2_TBL;
		m_values	VARCHAR2_TBL;
	BEGIN
		UTL_HTTP.set_wallet( i_wallet, null );
		UTL_HTTP.set_transfer_timeout( 60 );

		m_keys := VARCHAR2_TBL( 'username','password' );
		m_values := VARCHAR2_TBL( i_username, i_password );
		m_response := api( 'POST', '/sessions.json', VARCHAR2_TBL( 'username','password' ), VARCHAR2_TBL( i_username,i_password ) );

		l_credentials.id := json_ext.get_string( m_response, 'id' );
	END;


	---------------------------------------------------------------------------
	/*
	 */
	---------------------------------------------------------------------------

	FUNCTION begin_file_upload( i_filename IN VARCHAR2 )
	RETURN upload_t
	IS
		m_response json;
		m_keys		VARCHAR2_TBL;
		m_values	VARCHAR2_TBL;
		m_up			upload_t;
	BEGIN
		m_response := api( 'POST', '/files/' || i_filename, VARCHAR2_TBL( 'action' ), VARCHAR2_TBL( 'put' ) );

		m_up.ref := json_ext.get_string( m_response, 'ref' );
		m_up.path := json_ext.get_string( m_response, 'path' );
		m_up.action := json_ext.get_string( m_response, 'action' );
		m_up.ask_about_overwrites := json_ext.get_string( m_response, 'ask_about_overwrites' );
		m_up.expires := json_ext.get_string( m_response, 'expires' );
		m_up.partsize := json_ext.get_string( m_response, 'partsize' );
		m_up.next_partsize := json_ext.get_string( m_response, 'next_partsize' );
		m_up.part_number := json_ext.get_string( m_response, 'part_number' );
		m_up.available_parts := json_ext.get_string( m_response, 'available_parts' );
		m_up.uri := json_ext.get_string( m_response, 'upload_uri' );
		m_up.http_method := json_ext.get_string( m_response, 'http_method' );
		m_up.filename := i_filename;

		RETURN m_up;
	END;

	---------------------------------------------------------------------------
	/*
	 */
	---------------------------------------------------------------------------

	PROCEDURE write_file( i_upload IN OUT NOCOPY upload_t, i_text IN VARCHAR2 )
	IS
		m_temp_clob	CLOB;
	BEGIN
		m_temp_clob := i_text;
		i_upload.m_clob := i_upload.m_clob || m_temp_clob;
	END;

	---------------------------------------------------------------------------
	/*
	 */
	---------------------------------------------------------------------------

	PROCEDURE end_file_upload( i_upload IN OUT NOCOPY upload_t )
	IS
		m_ignore json;
	BEGIN
		flush( i_upload );
		m_ignore := api( 'POST', '/files/' || i_upload.filename, VARCHAR2_TBL( 'action','ref' ), VARCHAR2_TBL( 'end',i_upload.ref ) );
	END;
END;
/
show errors;
