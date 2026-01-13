<?php
// Simple endpoint to show the container hostname
header('Content-Type: text/plain');
// If no MoodleSession cookie is present, set one so sticky routing can use it.
if (empty($_COOKIE['MoodleSession'])) {
	// lightweight random id
	$id = bin2hex(random_bytes(8));
	setcookie('MoodleSession', $id, 0, '/');
}
echo "instance=" . gethostname() . "\n";
