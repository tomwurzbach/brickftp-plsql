CREATE OR REPLACE
PACKAGE pub.brickftp
AS
	TYPE upload_t IS RECORD (
		m_clob				CLOB,
		partsize			NUMBER,
		next_partsize	NUMBER,
		part_number		NUMBER,
		uri						VARCHAR2( 1000 ),
		http_method		VARCHAR2( 100 ),
		ref						VARCHAR2( 100 ),
		filename			VARCHAR2( 200 ),
		path					VARCHAR2( 200 ),
		action				VARCHAR2( 40 ),
		ask_about_overwrites	VARCHAR2( 10 ),
		expires				VARCHAR2( 30 ),
		available_parts	NUMBER
	);

	TYPE credentials_t IS RECORD (
		id						VARCHAR2( 100 )
	);

	PROCEDURE debug;
	PROCEDURE init( i_wallet IN VARCHAR2, i_username IN VARCHAR2, i_password IN VARCHAR2 );

	-- upload a file
	FUNCTION begin_file_upload( i_filename IN VARCHAR2 ) RETURN upload_t;
	PROCEDURE write_file( i_upload IN OUT NOCOPY upload_t, i_text IN VARCHAR2 );
	PROCEDURE end_file_upload( i_upload IN OUT NOCOPY upload_t );
END;
/

