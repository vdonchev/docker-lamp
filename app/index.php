<?php
$phpVersion = phpversion();
$hostname = gethostname();
$extensions = get_loaded_extensions();
$projectList = [];
if(file_exists('/config/projects/domains.conf')) {
    $list = file('/config/projects/domains.conf');
    if (file_exists('/config/projects/domains.local.conf')) {
        $list = array_merge($list, file('/config/projects/domains.local.conf'));
    }

    $projectList = array_filter(array_map('trim', $list));
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Local LAMP Environment</title>
    <style>
        body {
            font-family: "Segoe UI", sans-serif;
            background: #1e1e2f;
            color: #f1f1f1;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        .container {
            max-width: 800px;
            width: 100%;
            padding: 2rem;
            text-align: center;
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 0.2rem;
            color: #7fd1b9;
        }
        .subtitle {
            font-size: 1rem;
            color: #999;
            margin-bottom: 2rem;
        }
        .info-box {
            background: #2e2e3e;
            padding: 1rem;
            border-left: 4px solid #7fd1b9;
            margin: 1rem 0;
            text-align: left;
        }
        h2 {
            color: #7fd1b9;
            margin-top: 2rem;
        }
        ul {
            list-style: none;
            padding: 0;
            margin: 0.5rem 0;
        }
        li {
            margin: 0.25rem 0;
        }
        a {
            color: #7fd1b9;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .inline-list {
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 0.5rem;
            font-size: 0.9rem;
        }
        .inline-list span {
            background: #333;
            padding: 0.4rem 0.8rem;
            border-radius: 4px;
        }
        code {
            color: #aaa;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Welcome to Your Local LAMP Stack</h1>
    <div class="subtitle">Powered by Docker containers</div>

    <div class="info-box">
        <strong>Hostname:</strong> <?= htmlspecialchars($hostname) ?><br>
        <strong>PHP version:</strong> <?= $phpVersion ?>
    </div>

    <h2>Tools</h2>
    <ul>
        <li><a href="http://localhost:8080" target="_blank">phpMyAdmin</a> (if running)</li>
        <li><a href="http://localhost:8025" target="_blank">Mailpit</a> (if running)</li>
    </ul>

    <?php if (!empty($projectList)): ?>
        <h2>Local Projects</h2>
        <ul>
            <?php foreach ($projectList as $line):
                if (str_contains($line, ',') && !str_starts_with($line, '#')) {
                    [$domain, $path] = explode(',', $line, 2);
                    echo "<li><a target='_blank' href=\"http://$domain\">$domain</a> → <code>$path</code></li>";
                }
            endforeach; ?>
        </ul>
    <?php endif; ?>

    <h2>Loaded PHP Extensions</h2>
    <div class="inline-list">
        <?php foreach ($extensions as $ext): ?>
            <span><?= htmlspecialchars($ext) ?></span>
        <?php endforeach; ?>
    </div>
</div>
</body>
</html>
