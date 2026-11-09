// FuzSpeedrun autosplitter (Black Ops 7 on Kronos).
// The mod writes kronos/fuzspeedrun/live.json: LiveSplit only reads that file, never the game's memory.
state("cod25-cod") {}

init
{
    vars.path = Path.Combine(Path.GetDirectoryName(modules.First().FileName), "kronos", "fuzspeedrun", "live.json");
    vars.stamp = DateTime.MinValue;
    vars.status = "idle";
    vars.split = 0;
    vars.oldStatus = "idle";
    vars.oldSplit = 0;
    refreshRate = 20;
}

update
{
    vars.oldStatus = vars.status;
    vars.oldSplit = vars.split;
    try
    {
        DateTime stamp = File.GetLastWriteTimeUtc((string)vars.path);
        if (stamp != (DateTime)vars.stamp)
        {
            string text;
            using (var stream = new FileStream((string)vars.path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var reader = new StreamReader(stream))
            {
                text = reader.ReadToEnd();
            }
            var status = System.Text.RegularExpressions.Regex.Match(text, "\"status\"\\s*:\\s*\"(\\w+)\"");
            var split = System.Text.RegularExpressions.Regex.Match(text, "\"split\"\\s*:\\s*\"(\\d+)\"");
            // a file caught mid-write has no match: keep the old values and read it again next tick
            if (status.Success && split.Success)
            {
                bool first = (DateTime)vars.stamp == DateTime.MinValue;
                vars.stamp = stamp;
                vars.status = status.Groups[1].Value;
                vars.split = int.Parse(split.Groups[1].Value);
                // LiveSplit opened in the middle of a game: never start from a stale file
                if (first)
                {
                    vars.oldStatus = vars.status;
                    vars.oldSplit = vars.split;
                }
            }
        }
    }
    catch (IOException)
    {
    }
}

start
{
    return vars.status == "running" && vars.oldStatus != "running";
}

split
{
    return vars.split > vars.oldSplit;
}

reset
{
    return vars.oldStatus == "running" && vars.status == "idle";
}
