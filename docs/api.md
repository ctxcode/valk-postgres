
# Documentation

Namespaces: [main](#main)

---

# main

## Errors for 'main'

```js
// Thrown by every operation of this package.
+ error Error (connect, ssl, auth, unsupported, protocol, error, closed) payload { message: String, sqlstate: String (""), severity: String (""), detail: String (""), hint: String ("") }
```

## Enums for 'main'

```js
// How `connect` treats SSL.
+ enum SslMode { disable, prefer, require, verify_full }
// The kinds of `Value`.
+ enum TYPE { null, int, float, string, bool, array }
```

## Functions for 'main'

```js
// Opens a connection and logs in.
+ fn connect(host: String, user: String, password: String, db: ?String, port: u32 (5432), ssl: SslMode (SslMode.prefer)) Connection !Error
// Same as `connect`, with SSL settings beyond the mode: the CA file that the server certificate must lead to, and a client certificate for a server that asks for one.
+ fn connect_with(host: String, user: String, password: String, db: ?String, port: u32, ssl: SslOptions) Connection !Error
// Converts any supported value (integers, floats, bools, strings, json values, arrays of those, and nullable versions) into a `Value`.
+ fn convert(ndata: $T) Value
// Returns the connection as a `sql.Db`, the database type of the `valk-sql` package.
+ fn database(con: Connection) Db
```

## Classes for 'main'

```js
+ class Connection {
    // Rows affected by the last completed command (`INSERT`, `UPDATE`, `DELETE`, ...). For a `SELECT` it is the row count, known once every row has been fetched.
    ~ affected_rows: uint
    ~ closed: bool
    // Command tag of the last completed command, such as `INSERT 0 1`.
    ~ command_tag: String
    + debug: bool
    + debug_bytes: bool
    // Message of the last notice (`NOTICE`, `WARNING`, ...) the server sent.
    ~ last_notice: String
    // Notifications received through `LISTEN`, oldest first. Remove what you have handled.
    ~ notifications: Array[Notification]
    // Runtime parameters reported by the server, such as `server_version` and `TimeZone`.
    ~ parameters: Map[String]
    // Process id of the server backend serving this connection.
    ~ process_id: u32
    // Counts the statements that have run, so that the rows of a query can tell whether another statement took the connection from under them.
    ~+ query_serial: uint
    // Number of prepared statements kept per connection. Single statement queries are prepared once and reused while they stay in the cache.
    + statement_cache_size: uint
    // Transaction status of the last ReadyForQuery: 'I' idle, 'T' in a transaction, 'E' in a failed transaction.
    ~ transaction_status: u8

    // Runs `BEGIN`.
    + fn begin() void !Error
    // Binds a value to the `:name` placeholder of the next query.
    + fn bind(name: String, value: $T) void
    // Binds a value to the next `?` placeholder of the next query. Values that are not consumed by a `?` are bound to the `$1`, `$2`, ... placeholders in order.
    + fn bindv(value: $T) void
    // Removes the values bound with `bind` and `bindv`.
    + fn clear_binds() void
    // Closes the connection. Further calls throw `closed`.
    + fn close() void
    // Returns whether column `index` arrived in binary format. A prepared query that runs again receives integers, floats, bools, dates and timestamps in binary form; `col_view` then holds those bytes instead of text.
    + fn col_binary(index: uint) bool
    // Returns column `index` as a bool: true for `t`, `true`, `yes`, `on` and numbers other than 0.
    + fn col_bool(index: uint) bool
    // Returns the number of columns of the current result.
    + fn col_count() uint
    // Returns column `index` as a float, 0 for NULL or text that is not a number.
    + fn col_float(index: uint) float
    // Returns the index of the column named `name`.
    + fn col_index(name: String) uint !LookupError
    // Returns column `index` as an integer, 0 for NULL or text that is not a number.
    + fn col_int(index: uint) int
    // Returns whether column `index` of the current row is NULL (or missing).
    + fn col_is_null(index: uint) bool
    // Returns the name of column `index`, or "" when there is no such column.
    + fn col_name(index: uint) String
    // Returns column `index` as a new string, "" for NULL.
    + fn col_string(index: uint) String
    // Returns the type oid of column `index` (`pg_type.oid`), or 0 when there is no such column.
    + fn col_type(index: uint) uint
    // Returns column `index` as a `Value`, typed by the column type like `fetch_row` does.
    + fn col_value(index: uint) Value
    // Returns the bytes of column `index` as a view into the receive buffer, empty for NULL. The view is valid until the next row is read. See `col_binary`.
    + fn col_view(index: uint) &[u8]
    // Runs `COMMIT`.
    + fn commit() void !Error
    // Fetches every remaining row.
    + fn fetch_all() Array[Map[Value]] !Error
    // Fetches the next row and discards the rest. Returns null when there is no row.
    + fn fetch_one() ?Map[Value] !Error
    // Reads the next row into `row` (cleared first), keyed by column name. Returns false when there are no more rows. A query with several statements continues into the rows of the next statement.
    + fn fetch_row(row: Map[Value]) bool !Error
    // Returns whether a transaction is open (`BEGIN` was sent and not yet committed or rolled back).
    + fn in_transaction() bool
    // Reads the next row without building a map. Its columns are read with the `col_*` methods and stay valid until the next `next_row`, `fetch_row` or `query`. Returns false when there are no more rows.
    + fn next_row() bool !Error
    // Runs a query. Rows, if any, are read with `fetch_row`, `fetch_one` or `fetch_all`.
    + fn query(q: String, binds: ?Map[?Value] (null)) void !Error
    // Runs `ROLLBACK`.
    + fn rollback() void !Error
    // Returns the version string reported by the server (for example `16.4`).
    + fn server_version() String
    // Sets the socket read and write timeouts in milliseconds; 0 waits forever (the default).
    + fn set_timeouts(read_timeout_ms: uint, write_timeout_ms: uint) void
    // Returns whether the connection is encrypted with SSL.
    + fn ssl_enabled() bool
}
```

```js
// A notification received through `LISTEN`.
+ class Notification {
    // The channel name given to `NOTIFY`.
    + channel: String
    // The payload given to `NOTIFY`, or "".
    + payload: String
    // Process id of the backend that sent it.
    + process_id: u32
}
```

```js
// SSL settings for `connect_with`.
+ class SslOptions {
    // A PEM file with CA certificates to trust besides the system store, for a server certificate from a private CA. Only checked in `verify_full` mode.
    + ca_file: ?String
    // A PEM file with the client certificate, optionally followed by the intermediate certificates, sent when the server asks for one (`clientcert` in `pg_hba.conf`).
    + certificate_file: ?String
    // The password of an encrypted private key.
    + key_password: String
    // How SSL is used. The default verifies the server certificate and its host name.
    + mode: SslMode
    // The PEM private key of `certificate_file`. Null reads it from `certificate_file`.
    + private_key_file: ?String
}
```

```js
// A value read from a result row or bound to a query.
+ class Value {
    // The items when `type` is `array`.
    + array_items: ?Array[Value]
    // Which of the value kinds this is.
    + type: TYPE

    // Returns whether the value is NULL.
    + fn is_null() bool
    // Returns a NULL value.
    + static fn null() Value
    // Returns the value as a bool: `t`, `true`, `1`, `yes` and `on` are true for text, any number other than 0 is true.
    + fn to_bool() bool
    // Like `to_bool`, but null for NULL.
    + fn to_bool_or_null() ?bool
    // Returns the raw bytes of a `bytea` column (the server sends them hex encoded as `\x...`).
    + fn to_bytes() String
    // Returns the value as a float; text is parsed, NULL is 0.
    + fn to_float() float
    // Like `to_float`, but null for NULL.
    + fn to_float_or_null() ?float
    // Returns the value as an integer; text is parsed, floats are truncated, NULL is 0.
    + fn to_int() int
    // Like `to_int`, but null for NULL.
    + fn to_int_or_null() ?int
    // Parses a `json`/`jsonb` column. Returns json null when the text is not valid JSON.
    + fn to_json() Value
    // Like `to_json`, but null for NULL.
    + fn to_json_or_null() ?(Value)
    // Returns the value as text: the text the server sent, a number, `true`/`false`, or an array literal like `{1,2}`. NULL becomes "".
    + fn to_string() String
    // Like `to_string`, but null for NULL.
    + fn to_string_or_null() ?String
}
```
