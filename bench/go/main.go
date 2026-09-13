// Same scenarios as bench/valk and bench/rust, one connection, sequential
package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

const rows = 10000
const fetchRounds = 20

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func report(name string, ops int, start time.Time) {
	total := time.Since(start)
	fmt.Printf("RESULT %s %d %.1f %.0f\n", name, ops, float64(total.Microseconds())/1000, float64(ops)/total.Seconds())
}

func main() {
	host := "127.0.0.1"
	port := "5432"
	n := 20000
	if len(os.Args) > 1 {
		host = os.Args[1]
	}
	if len(os.Args) > 2 {
		port = os.Args[2]
	}
	if len(os.Args) > 3 {
		n, _ = strconv.Atoi(os.Args[3])
	}
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, fmt.Sprintf("postgres://test:root@%s:%s/valk_postgres_tests?sslmode=disable", host, port))
	must(err)
	defer conn.Close(ctx)

	// Setup
	_, err = conn.Exec(ctx, "DROP TABLE IF EXISTS bench_users")
	must(err)
	_, err = conn.Exec(ctx, "CREATE TABLE bench_users (id serial PRIMARY KEY, name text NOT NULL, score int NOT NULL, created timestamptz NOT NULL DEFAULT now())")
	must(err)
	_, err = conn.Exec(ctx, fmt.Sprintf("INSERT INTO bench_users (name, score) SELECT 'user' || g, g FROM generate_series(1, %d) AS g", rows))
	must(err)

	var id, score int32
	var name string
	var created time.Time

	// Warmup
	for i := 0; i < 200; i++ {
		_, err = conn.Exec(ctx, "SELECT 1")
		must(err)
		must(conn.QueryRow(ctx, "SELECT id, name, score FROM bench_users WHERE id = $1", i+1).Scan(&id, &name, &score))
	}

	// 1. Round trips: simple query
	start := time.Now()
	for i := 0; i < n; i++ {
		_, err = conn.Exec(ctx, "SELECT 1")
		must(err)
	}
	report("ping", n, start)

	// 2. Prepared statement with a parameter, one row
	start = time.Now()
	checksum := 0
	for i := 0; i < n; i++ {
		must(conn.QueryRow(ctx, "SELECT id, name, score FROM bench_users WHERE id = $1", (i%rows)+1).Scan(&id, &name, &score))
		checksum += int(score)
	}
	report("select_by_id", n, start)

	// 3. Fetch every row of the table
	start = time.Now()
	fetched := 0
	for i := 0; i < fetchRounds; i++ {
		rs, err := conn.Query(ctx, "SELECT id, name, score, created FROM bench_users")
		must(err)
		for rs.Next() {
			must(rs.Scan(&id, &name, &score, &created))
			checksum += int(id) + len(name)
			fetched++
		}
		must(rs.Err())
		rs.Close()
	}
	report("fetch_rows", fetched, start)

	// 4. Inserts inside one transaction
	start = time.Now()
	tx, err := conn.Begin(ctx)
	must(err)
	for i := 0; i < n; i++ {
		_, err = tx.Exec(ctx, "INSERT INTO bench_users (name, score) VALUES ($1, $2)", "new"+strconv.Itoa(i), i)
		must(err)
	}
	must(tx.Commit(ctx))
	report("insert", n, start)

	if checksum == 0 {
		fmt.Println("checksum: 0")
	}
}
