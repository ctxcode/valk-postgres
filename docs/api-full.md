
# Documentation

Namespaces: [main](#main)

---

# main

## Functions for 'main'

```js
// Opens a connection and logs in.
+ fn connect(host: String, user: String, password: String, db: ?String, port: u32 (5432), ssl: SslMode (SslMode.prefer)) Connection !Error
// Converts any supported value (integers, floats, bools, strings, json values, arrays of those, and nullable versions) into a `Value`.
+ fn convert(ndata: $T) Value
```

### connect

Opens a connection and logs in.

`db` is the database to connect to, or null for the database named after the user.
`ssl` decides whether the connection is upgraded to SSL before logging in (see `SslMode`).
Supported authentication methods: trust, password (cleartext), md5 and SCRAM-SHA-256.

### convert

Converts any supported value (integers, floats, bools, strings, json values, arrays of
those, and nullable versions) into a `Value`.

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

#### affected_rows

Rows affected by the last completed command (`INSERT`, `UPDATE`, `DELETE`, ...).
For a `SELECT` it is the row count, known once every row has been fetched.

#### command_tag

Command tag of the last completed command, such as `INSERT 0 1`.

#### last_notice

Message of the last notice (`NOTICE`, `WARNING`, ...) the server sent.

#### notifications

Notifications received through `LISTEN`, oldest first. Remove what you have handled.

#### parameters

Runtime parameters reported by the server, such as `server_version` and `TimeZone`.

#### process_id

Process id of the server backend serving this connection.

#### statement_cache_size

Number of prepared statements kept per connection. Single statement queries are
prepared once and reused while they stay in the cache.

#### transaction_status

Transaction status of the last ReadyForQuery: 'I' idle, 'T' in a transaction, 'E' in a failed transaction.

#### begin

Runs `BEGIN`.

#### bind

Binds a value to the `:name` placeholder of the next query.

#### bindv

Binds a value to the next `?` placeholder of the next query. Values that are not
consumed by a `?` are bound to the `$1`, `$2`, ... placeholders in order.

#### clear_binds

Removes the values bound with `bind` and `bindv`.

#### close

Closes the connection. Further calls throw `closed`.

#### col_binary

Returns whether column `index` arrived in binary format. A prepared query that runs
again receives integers, floats, bools, dates and timestamps in binary form;
`col_view` then holds those bytes instead of text.

#### col_bool

Returns column `index` as a bool: true for `t`, `true`, `yes`, `on` and numbers other than 0.

#### col_count

Returns the number of columns of the current result.

#### col_float

Returns column `index` as a float, 0 for NULL or text that is not a number.

#### col_index

Returns the index of the column named `name`.

#### col_int

Returns column `index` as an integer, 0 for NULL or text that is not a number.

#### col_is_null

Returns whether column `index` of the current row is NULL (or missing).

#### col_name

Returns the name of column `index`, or "" when there is no such column.

#### col_string

Returns column `index` as a new string, "" for NULL.

#### col_type

Returns the type oid of column `index` (`pg_type.oid`), or 0 when there is no such column.

#### col_value

Returns column `index` as a `Value`, typed by the column type like `fetch_row` does.

#### col_view

Returns the bytes of column `index` as a view into the receive buffer, empty for NULL.
The view is valid until the next row is read. See `col_binary`.

#### commit

Runs `COMMIT`.

#### fetch_all

Fetches every remaining row.

#### fetch_one

Fetches the next row and discards the rest. Returns null when there is no row.

#### fetch_row

Reads the next row into `row` (cleared first), keyed by column name. Returns false
when there are no more rows. A query with several statements continues into the
rows of the next statement.

#### in_transaction

Returns whether a transaction is open (`BEGIN` was sent and not yet committed or rolled back).

#### next_row

Reads the next row without building a map. Its columns are read with the `col_*`
methods and stay valid until the next `next_row`, `fetch_row` or `query`. Returns
false when there are no more rows.

#### query

Runs a query. Rows, if any, are read with `fetch_row`, `fetch_one` or `fetch_all`.

Values in `binds` are bound to `:name` placeholders. Values bound earlier with `bind`
and `bindv` are used as well. A single statement is prepared and cached, so that
running it again is cheaper. A query may also contain several statements separated
by `;`; it is then sent as is and cannot have bound values.

#### rollback

Runs `ROLLBACK`.

#### server_version

Returns the version string reported by the server (for example `16.4`).

#### set_timeouts

Sets the socket read and write timeouts in milliseconds; 0 waits forever (the default).

#### ssl_enabled

Returns whether the connection is encrypted with SSL.

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

### Notification

A notification received through `LISTEN`.

#### channel

The channel name given to `NOTIFY`.

#### payload

The payload given to `NOTIFY`, or "".

#### process_id

Process id of the backend that sent it.

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

### Value

A value read from a result row or bound to a query.

Integer columns become `int`, `float4`/`float8` columns `float`, `bool` columns `bool`
and every other column type (text, numeric, timestamps, json, uuid, bytea, ...) keeps
the text the server sent as `string`. The `to_*` methods convert between them.

#### array_items

The items when `type` is `array`.

#### type

Which of the value kinds this is.

#### is_null

Returns whether the value is NULL.

#### null

Returns a NULL value.

#### to_bool

Returns the value as a bool: `t`, `true`, `1`, `yes` and `on` are true for text, any number other than 0 is true.

#### to_bool_or_null

Like `to_bool`, but null for NULL.

#### to_bytes

Returns the raw bytes of a `bytea` column (the server sends them hex encoded as `\x...`).

Any other value is returned as its string form.

#### to_float

Returns the value as a float; text is parsed, NULL is 0.

#### to_float_or_null

Like `to_float`, but null for NULL.

#### to_int

Returns the value as an integer; text is parsed, floats are truncated, NULL is 0.

#### to_int_or_null

Like `to_int`, but null for NULL.

#### to_json

Parses a `json`/`jsonb` column. Returns json null when the text is not valid JSON.

#### to_json_or_null

Like `to_json`, but null for NULL.

#### to_string

Returns the value as text: the text the server sent, a number, `true`/`false`, or an array literal like `{1,2}`. NULL becomes "".

#### to_string_or_null

Like `to_string`, but null for NULL.
