<?php
$teams = explode("\n", file_get_contents($argv[1]));
$mapping = [];
foreach ($teams as $idx => $teamData) {
    if ($idx === 0)
    {
        continue;
    }
    $teamData = str_replace("\r", "", $teamData);
    IF (empty($teamData))
    {
        continue;
    }
    $teamData = explode("\t", $teamData);
    $mapping[str_replace('INST-', '', $teamData[7])][] = $teamData[0];
}
$sourceDir = $argv[2];
$domlogoDir = $argv[3];
if ($handle = opendir($sourceDir))
{
    while (($entry = readdir($handle)) !== false)
    {
        if (preg_match('/^\d+$/', $entry)) {
            if (!isset($mapping[$entry])) {
                echo "${entry} NOT FOUND!\n";
            } else {
                foreach ($mapping[$entry] as $team) {
                    $newName = sprintf('%s/%s.png', $domlogoDir, $team);
                    copy($sourceDir . '/' . $entry . '/logo.png', $newName);
                }
            }
        }
    }
    closedir($handle);
}
