CREATE TABLE Users (
	UserID integer PRIMARY KEY AUTOINCREMENT,
	Username varchar,
	Password varchar,
	Fullname varchar
);

CREATE TABLE Sessions (
	SessionID integer PRIMARY KEY AUTOINCREMENT,
	CreatedAt datetime,
	UserID integer
);

CREATE TABLE Notes (
	NoteID integer PRIMARY KEY AUTOINCREMENT,
	UserID integer,
	Title varchar,
	CreatedAt datetime,
	ModifiedAt datetime,
	Content text
);

CREATE TABLE Tags (
	TagID integer PRIMARY KEY AUTOINCREMENT,
	UserID integer,
	Title varchar
);

CREATE TABLE NoteTag (
	NoteID integer,
	TagID integer
);