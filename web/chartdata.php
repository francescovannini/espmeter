<?php

require_once("config.php");

$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
if ($mysqli->connect_errno) {
    die("Error: " . $mysqli->connect_error . "\n");
}

switch ($_GET["agg"]) {
    case "day":
        $source = "pulses_over_day";
        break;

    case "hour":
        $source = "pulses_over_hour";
        break;

    default:
        $source = "pulses_over_time";
        break;
}

ob_start("ob_gzhandler");
header('Content-Type: text/plain');
header('Cache-Control: no-cache');

printf("ts,m3,vcc\n");

if ($result = $mysqli->query(
    "SELECT ts, (pulses * 0.01) as m3, vcc FROM " . $source,
    MYSQLI_USE_RESULT
)) {
    while ($line = $result->fetch_assoc()) {
        printf("%s,%s,%.3f\n", $line["ts"], $line["m3"], $line["vcc"]);
    }
}

$mysqli->close();
