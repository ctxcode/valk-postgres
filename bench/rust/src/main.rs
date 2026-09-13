// Same scenarios as bench/valk and bench/go, one connection, sequential
use std::time::{Instant, SystemTime};
use tokio_postgres::NoTls;

const ROWS: i32 = 10000;
const FETCH_ROUNDS: usize = 20;

fn report(name: &str, ops: usize, start: Instant) {
    let total = start.elapsed();
    println!(
        "RESULT {} {} {:.1} {:.0}",
        name,
        ops,
        total.as_secs_f64() * 1000.0,
        ops as f64 / total.as_secs_f64()
    );
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    let host = args.get(1).cloned().unwrap_or("127.0.0.1".into());
    let port = args.get(2).cloned().unwrap_or("5432".into());
    let n: usize = args.get(3).and_then(|v| v.parse().ok()).unwrap_or(20000);

    let conn_str = format!("host={} port={} user=test password=root dbname=valk_postgres_tests", host, port);
    let (client, connection) = tokio_postgres::connect(&conn_str, NoTls).await.expect("connect");
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("connection error: {}", e);
        }
    });

    // Setup
    client.batch_execute("DROP TABLE IF EXISTS bench_users").await.unwrap();
    client
        .batch_execute("CREATE TABLE bench_users (id serial PRIMARY KEY, name text NOT NULL, score int NOT NULL, created timestamptz NOT NULL DEFAULT now())")
        .await
        .unwrap();
    client
        .batch_execute(&format!("INSERT INTO bench_users (name, score) SELECT 'user' || g, g FROM generate_series(1, {}) AS g", ROWS))
        .await
        .unwrap();

    let by_id = client.prepare("SELECT id, name, score FROM bench_users WHERE id = $1").await.unwrap();
    let fetch_all = client.prepare("SELECT id, name, score, created FROM bench_users WHERE id > $1").await.unwrap();

    // Warmup
    for i in 0..200i32 {
        client.simple_query("SELECT 1").await.unwrap();
        client.query_one(&by_id, &[&(i + 1)]).await.unwrap();
    }

    // 1. Round trips: simple query
    let start = Instant::now();
    for _ in 0..n {
        client.simple_query("SELECT 1").await.unwrap();
    }
    report("ping", n, start);

    // 2. Prepared statement with a parameter, one row
    let start = Instant::now();
    let mut checksum: i64 = 0;
    for i in 0..n {
        let id = (i as i32 % ROWS) + 1;
        let row = client.query_one(&by_id, &[&id]).await.unwrap();
        let score: i32 = row.get(2);
        let _name: &str = row.get(1);
        checksum += score as i64;
    }
    report("select_by_id", n, start);

    // 3. Fetch every row of the table
    let start = Instant::now();
    let mut fetched = 0usize;
    for _ in 0..FETCH_ROUNDS {
        let rows = client.query(&fetch_all, &[&0i32]).await.unwrap();
        for row in &rows {
            let id: i32 = row.get(0);
            let name: &str = row.get(1);
            let _score: i32 = row.get(2);
            let _created: SystemTime = row.get(3);
            checksum += id as i64 + name.len() as i64;
            fetched += 1;
        }
    }
    report("fetch_rows", fetched, start);

    // 4. Inserts inside one transaction
    let start = Instant::now();
    let mut client = client;
    let tx = client.transaction().await.unwrap();
    let insert = tx.prepare("INSERT INTO bench_users (name, score) VALUES ($1, $2)").await.unwrap();
    for i in 0..n {
        let name = format!("new{}", i);
        tx.execute(&insert, &[&name, &(i as i32)]).await.unwrap();
    }
    tx.commit().await.unwrap();
    report("insert", n, start);

    if checksum == 0 {
        println!("checksum: 0");
    }
}
