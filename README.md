# jschan-cli
CLI client for jschan made with powershell.

# How to use

## Powershell 7 (Windows / Linux / MacOS)

```
pwsh ./ptchina.ps1
```

## Windows Powershell 5

Windows Powershell 5 (the default powershell, that comes installed on Windows) doesnt allow you to run scripts by default, you need to bypass the execution policy or change your execution policy.  

```
powershell.exe -ExecutionPolicy Bypass -File ./ptchina.ps1
```

# Custom themes

To use your own theme just create on on `themes.json` and run:

```
jschan-cli.ps1 -style "name"
```
