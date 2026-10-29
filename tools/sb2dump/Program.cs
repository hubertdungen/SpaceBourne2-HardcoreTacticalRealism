// Dumps SpaceBourne 2 Blueprint packages (exports + Kismet bytecode) to JSON.
// usage: sb2dump <pakDir> <oodleDll> <outDir> <regex> [regex...]
using System.Text.RegularExpressions;
using CUE4Parse.Compression;
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Versions;
using Newtonsoft.Json;

var pakDir = args[0];
var oodle = args[1];
var outDir = args[2];
var patterns = args.Skip(3).Select(p => new Regex(p, RegexOptions.IgnoreCase)).ToArray();

OodleHelper.Initialize(oodle);

var provider = new DefaultFileProvider(pakDir, SearchOption.TopDirectoryOnly,
    new VersionContainer(EGame.GAME_UE4_27), StringComparer.OrdinalIgnoreCase);
provider.ReadScriptData = true;
provider.Initialize();
provider.Mount();
Console.WriteLine($"files: {provider.Files.Count}");

int n = 0, fail = 0;
foreach (var path in provider.Files.Keys.Where(k => k.EndsWith(".uasset", StringComparison.OrdinalIgnoreCase)).OrderBy(k => k))
{
    if (!patterns.Any(r => r.IsMatch(path))) continue;
    var dst = Path.Combine(outDir, path.Replace('/', Path.DirectorySeparatorChar)) + ".json";
    Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
    try
    {
        var pkg = provider.LoadPackage(path);
        var list = new List<object>();
        foreach (var lazy in pkg.ExportsLazy)
        {
            try { list.Add(lazy.Value); }
            catch (Exception e) { list.Add(new { Error = e.GetType().Name + ": " + e.Message }); fail++; }
        }
        File.WriteAllText(dst, JsonConvert.SerializeObject(list, Formatting.Indented));
        n++;
    }
    catch (Exception e)
    {
        File.WriteAllText(dst, "ERROR " + e);
        fail++;
    }
}
Console.WriteLine($"dumped {n} packages, {fail} errors");

