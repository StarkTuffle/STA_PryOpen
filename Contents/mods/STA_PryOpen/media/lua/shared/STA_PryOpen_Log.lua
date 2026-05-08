local Log = {}

Log.TAG = "STA_PryOpen"
Log.levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4, TRACE = 5 }
Log.current = 2

local function side()
    if isServer() then return "Server"
    elseif isClient() then return "Client"
    else return "SP" end
end

local function now()
    return os.date and os.date("%H:%M:%S") or ""
end

local function fmt(msg, ...)
    if select("#", ...) > 0 then
        local ok, out = pcall(string.format, tostring(msg), ...)
        if ok then return out end
    end
    return tostring(msg)
end

local function write(lvl, msg, ...)
    if Log.current < lvl then return end
    print(string.format("[%s][%s][%s][%s] %s",
        Log.TAG, side(), now(),
    (lvl == Log.levels.ERROR and "ERROR")
    or(lvl == Log.levels.WARN and "WARN")
    or (lvl == Log.levels.INFO and "INFO")
    or (lvl == Log.levels.DEBUG and "DEBUG")
    or "TRACE",
    fmt(msg, ...)))
end

function Log.error(msg, ...) write(Log.levels.ERROR, msg, ...) end
function Log.warn(msg, ...) write(Log.levels.WARN, msg, ...) end
function Log.info(msg, ...) write(Log.levels.INFO, msg, ...) end
function Log.debug(msg, ...) write(Log.levels.DEBUG, msg, ...) end
function Log.trace(msg, ...) write(Log.levels.TRACE, msg, ...) end

_G.STA_PryOpen_Log = Log
return Log