<?php

require_once("config.php");

$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
if ($mysqli->connect_errno) {
    die("Error: " . $mysqli->connect_error . "\n");
}

ob_start("ob_gzhandler");
header('Content-Type: text/plain');
header('Cache-Control: no-cache');

printf("ts,dm3\n");

if ($result = $mysqli->query("SELECT ts, (pulses * 10) as dm3 FROM pulses_over_time", MYSQLI_USE_RESULT)) {
    while ($line = $result->fetch_assoc()) {
        printf("%s,%s\n", $line['ts'], $line['dm3']);
    }
}

$mysqli->close();
