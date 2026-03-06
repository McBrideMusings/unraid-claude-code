<?PHP
$PLUGIN_DIR = "/boot/config/plugins/claude-code";
$CONFIG_DIR = "{$PLUGIN_DIR}/claude-config";
$BIN_CACHE  = "{$PLUGIN_DIR}/bin/claude";
$BIN_PATH   = "/usr/local/bin/claude";

function getClaudeVersion() {
  global $BIN_PATH;
  // Check primary location, then native install location
  $paths = [$BIN_PATH, '/root/.local/bin/claude'];
  foreach ($paths as $p) {
    if (file_exists($p)) {
      $out = trim(shell_exec("{$p} --version 2>/dev/null"));
      if ($out) return $out;
    }
  }
  return false;
}

function getAuthStatus() {
  global $CONFIG_DIR;
  // Check for OAuth token files in the config directory
  $authFiles = glob("{$CONFIG_DIR}/.credentials*");
  if (!empty($authFiles)) return true;
  // Also check for auth.json
  if (file_exists("{$CONFIG_DIR}/auth.json")) return true;
  // Check credentialstore directory
  if (is_dir("{$CONFIG_DIR}/credentialstore") && count(glob("{$CONFIG_DIR}/credentialstore/*")) > 0) return true;
  return false;
}

function getClaudeMd() {
  global $CONFIG_DIR;
  $path = "{$CONFIG_DIR}/CLAUDE.md";
  if (file_exists($path)) return file_get_contents($path);
  return "";
}

function getSettingsJson() {
  global $CONFIG_DIR;
  $path = "{$CONFIG_DIR}/settings.json";
  if (file_exists($path)) return file_get_contents($path);
  return "{}";
}

function getSkillsList() {
  global $CONFIG_DIR;
  $skills = [];
  $pluginsDir = "{$CONFIG_DIR}/plugins";
  if (!is_dir($pluginsDir)) return $skills;

  $iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($pluginsDir, RecursiveDirectoryIterator::SKIP_DOTS)
  );
  foreach ($iterator as $file) {
    if ($file->isFile() && $file->getExtension() === 'md') {
      $skills[] = [
        'name' => $file->getFilename(),
        'path' => $file->getPathname()
      ];
    }
  }
  return $skills;
}

function updateClaudeBinary() {
  // The update script handles native binary download with checksum verification.
  // We just invoke it and report the result.
  $script = "/usr/local/emhttp/plugins/claude-code/scripts/update-claude";
  $output = shell_exec("bash {$script} 2>&1");
  $version = getClaudeVersion();
  if ($version) {
    return ['success' => true, 'version' => $version, 'output' => $output];
  }
  return ['success' => false, 'error' => 'Update failed', 'output' => $output];
}

// API request handler — only runs when called directly (not when included)
if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'claude-code-api.php' && isset($_GET['action'])) {
  header('Content-Type: application/json');

  switch ($_GET['action']) {
    case 'status':
      echo json_encode([
        'version' => getClaudeVersion() ?: null,
        'authenticated' => getAuthStatus()
      ]);
      break;

    case 'update':
      echo json_encode(updateClaudeBinary());
      break;

    case 'save-claude-md':
      $content = $_POST['content'] ?? '';
      $path = "{$CONFIG_DIR}/CLAUDE.md";
      if (!is_dir($CONFIG_DIR)) mkdir($CONFIG_DIR, 0755, true);
      $ok = file_put_contents($path, $content);
      echo json_encode(['success' => $ok !== false]);
      break;

    case 'save-settings-json':
      $content = $_POST['content'] ?? '';
      $path = "{$CONFIG_DIR}/settings.json";
      if (!is_dir($CONFIG_DIR)) mkdir($CONFIG_DIR, 0755, true);
      $ok = file_put_contents($path, $content);
      echo json_encode(['success' => $ok !== false]);
      break;

    case 'read-claude-md':
      echo json_encode(['success' => true, 'content' => getClaudeMd()]);
      break;

    case 'read-settings-json':
      echo json_encode(['success' => true, 'content' => getSettingsJson()]);
      break;

    case 'read-skill':
      $path = $_GET['path'] ?? '';
      // Security: only allow reading from the plugins directory
      $realPath = realpath($path);
      $allowedBase = realpath("{$CONFIG_DIR}/plugins");
      if ($realPath && $allowedBase && strpos($realPath, $allowedBase) === 0) {
        echo json_encode(['success' => true, 'content' => file_get_contents($realPath)]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    case 'save-skill':
      $path = $_POST['path'] ?? '';
      $content = $_POST['content'] ?? '';
      $realPath = realpath($path);
      $allowedBase = realpath("{$CONFIG_DIR}/plugins");
      if ($realPath && $allowedBase && strpos($realPath, $allowedBase) === 0) {
        $ok = file_put_contents($realPath, $content);
        echo json_encode(['success' => $ok !== false]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    default:
      echo json_encode(['success' => false, 'error' => 'Unknown action']);
  }
  exit;
}
?>
