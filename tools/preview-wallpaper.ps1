#requires -Version 5.1
param([Parameter(Mandatory)] [string]$Directory, [int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
"Wallpaper preview: http://127.0.0.1:$Port/"
try {
    while ($listener.IsListening) {
        $request = $listener.GetContext()
        try {
            $path = $request.Request.Url.AbsolutePath
            $file = switch ($path) {
                '/' { 'index.html' }
                '/index.html' { 'index.html' }
                '/motion.js' { 'motion.js' }
                '/image.png' { 'image.png' }
                '/missing/index.html' { 'index.html' }
                '/missing/motion.js' { 'motion.js' }
            }
            $full = if ($file) { Join-Path $Directory $file } else { $null }
            if ($full -and (Test-Path -LiteralPath $full)) {
                $request.Response.ContentType = switch ([IO.Path]::GetExtension($full)) { '.html' { 'text/html; charset=utf-8' } '.js' { 'text/javascript; charset=utf-8' } '.png' { 'image/png' } }
                $bytes = [IO.File]::ReadAllBytes($full)
                $request.Response.ContentLength64 = $bytes.Length
                $request.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            else { $request.Response.StatusCode = 404 }
        }
        finally { $request.Response.Close() }
    }
}
finally { $listener.Close() }
