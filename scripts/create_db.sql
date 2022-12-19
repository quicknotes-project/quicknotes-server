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

CREATE TRIGGER PURGE_UNATTACHED_TAGS_ON_DELETE
	AFTER DELETE ON NoteTag
	WHEN NOT EXISTS(SELECT * FROM NoteTag WHERE TagID = old.TagID)
BEGIN
	DELETE FROM Tags WHERE TagID = old.TagID
END;

CREATE TRIGGER PURGE_UNATTACHED_TAGS_ON_UPDATE
	AFTER UPDATE ON NoteTag
	WHEN old.TagID <> new.TagID AND
		NOT EXISTS(SELECT * FROM NoteTag WHERE TagID = old.TagID)
BEGIN
	DELETE FROM Tags WHERE TagID = old.TagID
END;