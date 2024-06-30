// For Windows systems
// +build windows

package swagger

//go:generate powershell -Command "if (Test-Path server) { Remove-Item -Recurse -Force server }"
//go:generate powershell -Command "New-Item -ItemType Directory -Force -Path server"
//go:generate swagger generate server --quiet --target server --name hello-api --spec swagger.yml --exclude-main
