<?php

require_once("config.php");

function parse_log($body)
{

	global $now;

	$data = json_decode($body);
	$log_ts = $data->ts;
	$drift = $now - $log_ts;

	if (!isset($data->dt)) {
		return;
	}

	$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
	if ($mysqli->connect_errno) {
		die("Error: " . $mysqli->connect_error . "\n");
	}

	if (!$mysqli->begin_transaction(MYSQLI_TRANS_START_READ_WRITE)) {
		die("Failed beginning transaction: " . $mysqli->error . "\n");
	}

	$mysqli->autocommit(FALSE);

	// Beginning of the 24h log
	$log_begin = $data->ts - $drift - (3600 * 24);

	$stmt = $mysqli->prepare("INSERT INTO log (ts, timedrift) VALUES (FROM_UNIXTIME(?), ?)");
	$stmt->bind_param("ii", $now, $drift);
	if (!$stmt->execute()) {
		die("Failed inserting new log: " . $mysqli->error . "\n");
	}

	if (!($result = $mysqli->query("SELECT LAST_INSERT_ID()"))) {
		die("Failed retrieving log ID: " . $mysqli->error . "\n");
	}

	$log_id = $result->fetch_array(MYSQLI_NUM)[0];

	foreach ($data->dt as $hour => $content) {

		// Insert battery voltage (sampled every 3 hours)
		$vcc_ts = $log_begin + $hour * 3 * 3600;
		$stmt = $mysqli->prepare("INSERT INTO vcc (idlog, ts, vcc) VALUES (?, FROM_UNIXTIME(?), ?)");
		$stmt->bind_param("iid", $log_id, $vcc_ts, $content->v * VCC_ADJ);
		if (!$stmt->execute()) {
			die("Failed inserting VCC log: " . $mysqli->error . "\n");
		}

		// Insert samples
		$c = $hour * 36; // 36 slots of 5 minutes every 3 hours
		foreach ($content->f as $s) {
			$stmt = $mysqli->prepare("INSERT INTO counter (idlog, slot, pulses) VALUES (?, ?, ?)");
			$stmt->bind_param("iii", $log_id, $c, $s);
			if (!$stmt->execute()) {
				die("Failed inserting counter log: " . $mysqli->error . "\n");
			}
			$c++;
		}
	}

	if (!$mysqli->commit()) {
		die("Failed committing transaction: " . $mysqli->error . "\n");
	}

	$mysqli->close();
}
