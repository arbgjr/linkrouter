#Requires AutoHotkey v2.0
#SingleInstance Force

cfgPath := "C:\tools\LinkRouter\linkrouter.config.json"
logPath := A_Temp "\linkrouter_debug.log"  ; fallback default

if (A_Args.Length < 1) {
    LogLine("unknown", "none", "none", 0, "none", "missing_url_argument", "")
    ExitApp
}

url := A_Args[1]

origin := "unknown"
try {
    hwnd := WinGetID("A")
    pid := WinGetPID("ahk_id " hwnd)
    origin := ProcessGetName(pid)
} catch as e {
    origin := "unknown"
}

try cfg := LoadConfig(cfgPath)
catch as e {
    LogLine(origin, "none", "none", 0, "none", "config_error", e.Message)
    ExitApp
}

; Obter logPath do config (se existir)
if (cfg.Has("logPath")) {
    logPath := cfg["logPath"]
    ; Criar diretório se não existir
    logDir := RegExReplace(logPath, "[^\\]*$", "")
    if (logDir != "" && !DirExist(logDir)) {
        try DirCreate(logDir)
    }
}

decided := cfg["default"]
rules := cfg.Has("rules") ? cfg["rules"] : Map()

if (rules is Map) {
    if (rules.Has(origin))
        decided := rules[origin]
}

browsers := cfg["browsers"]
if !(browsers is Map) {
    LogLine(origin, decided, "none", 0, "none", "config_error", "browsers_is_not_object")
    ExitApp
}

if !browsers.Has(decided) {
    LogLine(origin, decided, "none", 0, "none", "browser_not_found", "")
    ExitApp
}

exe := browsers[decided]
if !FileExist(exe) {
    LogLine(origin, decided, exe, 0, "none", "exe_not_found", "")
    ExitApp
}

pidLaunched := 0
procLaunched := "unknown"
runErr := ""

try {
    Run('"' exe '" "' url '"', , , &pidLaunched)

    if (pidLaunched) {

        ; retry por até 2s para pegar nome pelo PID
        procLaunched := "pid_lookup_failed"
        start := A_TickCount
        while (A_TickCount - start) < 2000 {
            try {
                procLaunched := ProcessGetName(pidLaunched)
                break
            } catch as e {
                Sleep 80
            }
        }

        ; fallback: confirma se o exe decidido está rodando
        if (procLaunched = "pid_lookup_failed") {
            exeName := RegExReplace(exe, "i)^.*\\", "")
            try {
                if ProcessExist(exeName)
                    procLaunched := exeName
                else
                    procLaunched := "not_running_after_run"
            } catch as e {
                procLaunched := "fallback_failed"
            }
        }

    } else {
        procLaunched := "no_pid_returned"
    }

} catch as e {
    runErr := e.Message
    procLaunched := "run_failed"
}

LogLine(origin, decided, exe, pidLaunched, procLaunched, url, runErr)
ExitApp

LogLine(origin, decided, exe, pid, procLaunched, url, errMsg) {
    global logPath
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    line := ts
        . " | origin=" origin
        . " | decided=" decided
        . " | exe=" exe
        . " | launched_pid=" pid
        . " | launched_proc=" procLaunched
        . " | url=" url
    if (errMsg != "")
        line .= " | err=" errMsg
    line .= "`n"
    FileAppend line, logPath, "UTF-8"
}

LoadConfig(path) {
    if !FileExist(path)
        throw Error("config_not_found: " path)

    txt := FileRead(path, "UTF-8")
    obj := Json_Parse(txt)

    if !(obj is Map)
        throw Error("config_root_not_object")

    if !obj.Has("default")
        throw Error("missing_field: default")

    if !obj.Has("browsers")
        throw Error("missing_field: browsers")

    return obj
}

; ============================
; JSON parser (AHK v2 puro)
; Suporta: objects, arrays, strings, numbers, true, false, null
; Retorna: Map e Array
; ============================
Json_Parse(text) {
    p := Json_Parser(text)
    return p.Parse()
}

class Json_Parser {
    __New(text) {
        this.s := text
        this.i := 1
        this.len := StrLen(text)
    }

    Parse() {
        this.SkipWS()
        val := this.ParseValue()
        this.SkipWS()
        return val
    }

    SkipWS() {
        while (this.i <= this.len) {
            ch := SubStr(this.s, this.i, 1)
            if (ch = " " || ch = "`t" || ch = "`r" || ch = "`n")
                this.i++
            else
                break
        }
    }

    ParseValue() {
        this.SkipWS()
        if (this.i > this.len)
            throw Error("json_unexpected_eof")

        ch := SubStr(this.s, this.i, 1)

        if (ch = "{")
            return this.ParseObject()
        if (ch = "[")
            return this.ParseArray()
        if (ch = '"')
            return this.ParseString()

        if (SubStr(this.s, this.i, 4) = "true") {
            this.i += 4
            return true
        }
        if (SubStr(this.s, this.i, 5) = "false") {
            this.i += 5
            return false
        }
        if (SubStr(this.s, this.i, 4) = "null") {
            this.i += 4
            return ""
        }

        ; number
        return this.ParseNumber()
    }

    ParseObject() {
        obj := Map()
        this.i++ ; skip {
        this.SkipWS()

        if (SubStr(this.s, this.i, 1) = "}") {
            this.i++
            return obj
        }

        loop {
            this.SkipWS()
            if (SubStr(this.s, this.i, 1) != '"')
                throw Error("json_expected_string_key")

            key := this.ParseString()

            this.SkipWS()
            if (SubStr(this.s, this.i, 1) != ":")
                throw Error("json_expected_colon")
            this.i++ ; skip :

            val := this.ParseValue()
            obj[key] := val

            this.SkipWS()
            ch := SubStr(this.s, this.i, 1)
            if (ch = "}") {
                this.i++
                return obj
            }
            if (ch != ",")
                throw Error("json_expected_comma_or_end_object")
            this.i++ ; skip ,
        }
    }

    ParseArray() {
        arr := []
        this.i++ ; skip [
        this.SkipWS()

        if (SubStr(this.s, this.i, 1) = "]") {
            this.i++
            return arr
        }

        loop {
            val := this.ParseValue()
            arr.Push(val)

            this.SkipWS()
            ch := SubStr(this.s, this.i, 1)
            if (ch = "]") {
                this.i++
                return arr
            }
            if (ch != ",")
                throw Error("json_expected_comma_or_end_array")
            this.i++ ; skip ,
        }
    }

    ParseString() {
        if (SubStr(this.s, this.i, 1) != '"')
            throw Error("json_expected_quote")

        this.i++ ; skip opening quote
        out := ""

        while (this.i <= this.len) {
            ch := SubStr(this.s, this.i, 1)

            if (ch = '"') {
                this.i++
                return out
            }

            if (ch = "\") {
                this.i++
                if (this.i > this.len)
                    throw Error("json_bad_escape")

                esc := SubStr(this.s, this.i, 1)
                if (esc = '"' || esc = "\" || esc = "/")
                    out .= esc
                else if (esc = "b")
                    out .= Chr(8)
                else if (esc = "f")
                    out .= Chr(12)
                else if (esc = "n")
                    out .= "`n"
                else if (esc = "r")
                    out .= "`r"
                else if (esc = "t")
                    out .= "`t"
                else if (esc = "u") {
                    hex := SubStr(this.s, this.i + 1, 4)
                    if !RegExMatch(hex, "i)^[0-9a-f]{4}$")
                        throw Error("json_bad_unicode_escape")
                    code := Integer("0x" hex)
                    out .= Chr(code)
                    this.i += 4
                } else {
                    throw Error("json_bad_escape")
                }
                this.i++
                continue
            }

            out .= ch
            this.i++
        }

        throw Error("json_unterminated_string")
    }

    ParseNumber() {
        start := this.i

        ch := SubStr(this.s, this.i, 1)
        if (ch = "-")
            this.i++

        ; int
        if (SubStr(this.s, this.i, 1) = "0") {
            this.i++
        } else {
            if !RegExMatch(SubStr(this.s, this.i, 1), "^\d$")
                throw Error("json_invalid_number")
            while (this.i <= this.len && RegExMatch(SubStr(this.s, this.i, 1), "^\d$"))
                this.i++
        }

        ; frac
        if (SubStr(this.s, this.i, 1) = ".") {
            this.i++
            if !RegExMatch(SubStr(this.s, this.i, 1), "^\d$")
                throw Error("json_invalid_number")
            while (this.i <= this.len && RegExMatch(SubStr(this.s, this.i, 1), "^\d$"))
                this.i++
        }

        ; exp
        ch := SubStr(this.s, this.i, 1)
        if (ch = "e" || ch = "E") {
            this.i++
            ch2 := SubStr(this.s, this.i, 1)
            if (ch2 = "+" || ch2 = "-")
                this.i++
            if !RegExMatch(SubStr(this.s, this.i, 1), "^\d$")
                throw Error("json_invalid_number")
            while (this.i <= this.len && RegExMatch(SubStr(this.s, this.i, 1), "^\d$"))
                this.i++
        }

        numStr := SubStr(this.s, start, this.i - start)
        return numStr + 0
    }
}
