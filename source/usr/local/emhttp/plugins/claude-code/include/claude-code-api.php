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

function parseFrontMatter($content) {
  $result = ['name' => '', 'description' => ''];
  if (preg_match('/\A---\s*\n(.*?)\n---/s', $content, $m)) {
    if (preg_match('/^name:\s*(.+)$/m', $m[1], $n)) $result['name'] = trim($n[1]);
    if (preg_match('/^description:\s*(.+)$/m', $m[1], $d)) $result['description'] = trim($d[1]);
  }
  return $result;
}

function sanitizeFilename($name) {
  $name = strtolower(trim($name));
  $name = preg_replace('/[^a-z0-9\-]/', '-', $name);
  $name = preg_replace('/-+/', '-', $name);
  $name = trim($name, '-');
  if (!$name) return false;
  if (substr($name, -3) !== '.md') $name .= '.md';
  return $name;
}

function getFileTypeDir($type) {
  global $CONFIG_DIR;
  $dirs = [
    'skill' => "{$CONFIG_DIR}/skills",
    'command' => "{$CONFIG_DIR}/commands",
  ];
  return $dirs[$type] ?? false;
}

function listFiles($type) {
  $dir = getFileTypeDir($type);
  if (!$dir || !is_dir($dir)) return [];
  $files = [];
  foreach (glob("{$dir}/*.md") as $path) {
    $content = file_get_contents($path);
    $fm = parseFrontMatter($content);
    $files[] = [
      'filename' => basename($path),
      'path' => $path,
      'name' => $fm['name'] ?: basename($path, '.md'),
      'description' => $fm['description'],
    ];
  }
  usort($files, function($a, $b) { return strcasecmp($a['filename'], $b['filename']); });
  return $files;
}

function getSkillsList() {
  return listFiles('skill');
}

function getCommandsList() {
  return listFiles('command');
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

    case 'list-files':
      $type = $_GET['type'] ?? '';
      if (!in_array($type, ['skill', 'command'])) {
        echo json_encode(['success' => false, 'error' => 'Invalid type']);
        break;
      }
      echo json_encode(['success' => true, 'files' => listFiles($type)]);
      break;

    case 'read-file':
      $type = $_GET['type'] ?? '';
      $path = $_GET['path'] ?? '';
      $baseDir = getFileTypeDir($type);
      if (!$baseDir) { echo json_encode(['success' => false, 'error' => 'Invalid type']); break; }
      $realPath = realpath($path);
      $realBase = realpath($baseDir);
      if ($realPath && $realBase && strpos($realPath, $realBase) === 0) {
        echo json_encode(['success' => true, 'content' => file_get_contents($realPath)]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    case 'create-file':
      $type = $_POST['type'] ?? '';
      $name = $_POST['name'] ?? '';
      $baseDir = getFileTypeDir($type);
      if (!$baseDir) { echo json_encode(['success' => false, 'error' => 'Invalid type']); break; }
      $filename = sanitizeFilename($name);
      if (!$filename) { echo json_encode(['success' => false, 'error' => 'Invalid filename']); break; }
      if (!is_dir($baseDir)) mkdir($baseDir, 0755, true);
      $filePath = "{$baseDir}/{$filename}";
      if (file_exists($filePath)) { echo json_encode(['success' => false, 'error' => 'File already exists']); break; }
      $displayName = basename($filename, '.md');
      $ucName = ucfirst(str_replace('-', ' ', $displayName));
      if ($type === 'command') {
        $template = "---\nname: {$displayName}\ndescription: Describe what this command does\nuser_invocable: true\n---\n\n# {$ucName}\n\nCommand instructions go here.\n";
      } else {
        $template = "---\nname: {$displayName}\ndescription: Describe when this skill should be used\n---\n\n# {$ucName}\n\nSkill instructions go here.\n";
      }
      $ok = file_put_contents($filePath, $template);
      echo json_encode(['success' => $ok !== false, 'path' => $filePath, 'content' => $template]);
      break;

    case 'save-file':
      $type = $_POST['type'] ?? '';
      $path = $_POST['path'] ?? '';
      $content = $_POST['content'] ?? '';
      $baseDir = getFileTypeDir($type);
      if (!$baseDir) { echo json_encode(['success' => false, 'error' => 'Invalid type']); break; }
      $realPath = realpath($path);
      $realBase = realpath($baseDir);
      if ($realPath && $realBase && strpos($realPath, $realBase) === 0) {
        $ok = file_put_contents($realPath, $content);
        echo json_encode(['success' => $ok !== false]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    case 'delete-file':
      $type = $_POST['type'] ?? '';
      $path = $_POST['path'] ?? '';
      $baseDir = getFileTypeDir($type);
      if (!$baseDir) { echo json_encode(['success' => false, 'error' => 'Invalid type']); break; }
      $realPath = realpath($path);
      $realBase = realpath($baseDir);
      if ($realPath && $realBase && strpos($realPath, $realBase) === 0) {
        $ok = unlink($realPath);
        echo json_encode(['success' => $ok]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    // Legacy endpoints for backward compatibility
    case 'read-skill':
      $path = $_GET['path'] ?? '';
      $realPath = realpath($path);
      $allowedBases = [realpath("{$CONFIG_DIR}/plugins"), realpath("{$CONFIG_DIR}/skills")];
      $valid = false;
      foreach ($allowedBases as $base) {
        if ($realPath && $base && strpos($realPath, $base) === 0) { $valid = true; break; }
      }
      if ($valid) {
        echo json_encode(['success' => true, 'content' => file_get_contents($realPath)]);
      } else {
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
      }
      break;

    case 'save-skill':
      $path = $_POST['path'] ?? '';
      $content = $_POST['content'] ?? '';
      $realPath = realpath($path);
      $allowedBases = [realpath("{$CONFIG_DIR}/plugins"), realpath("{$CONFIG_DIR}/skills")];
      $valid = false;
      foreach ($allowedBases as $base) {
        if ($realPath && $base && strpos($realPath, $base) === 0) { $valid = true; break; }
      }
      if ($valid) {
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
