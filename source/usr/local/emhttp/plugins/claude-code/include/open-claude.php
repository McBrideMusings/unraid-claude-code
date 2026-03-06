<?PHP
/* Launch Claude Code in a ttyd web terminal */
$docroot ??= ($_SERVER['DOCUMENT_ROOT'] ?: '/usr/local/emhttp');
require_once "$docroot/webGui/include/Secure.php";

$sock = "/var/run/claude-code.sock";

// Kill any existing claude ttyd session so we get a fresh one
exec('pgrep --ns $$ -f ' . escapeshellarg($sock), $pids);
foreach ($pids as $pid) {
  exec("kill $pid 2>/dev/null");
}
usleep(200000);

// Launch ttyd running claude in /root
// -s9 = send SIGKILL on close, -om1 = max 1 client
exec("ttyd-exec -s9 -om1 -i '$sock' bash -lc 'export PATH=\"\$HOME/.local/bin:\$PATH\" && cd /root && exec claude' &>/dev/null &");
?>
