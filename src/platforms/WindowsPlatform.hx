package platforms;


import haxe.io.Path;
import haxe.Template;
import helpers.AssetHelper;
import helpers.FileHelper;
import helpers.IconHelper;
import helpers.NekoHelper;
import helpers.PathHelper;
import helpers.PlatformHelper;
import helpers.ProcessHelper;
import project.AssetType;
import project.OpenFLProject;
import sys.io.File;
import sys.FileSystem;


class WindowsPlatform implements IPlatformTool {
	
	
	private var applicationDirectory:String;
	private var executablePath:String;
	private var targetDirectory:String;
	private var useNeko:Bool;
	
	
	public function build (project:OpenFLProject):Void {
		
		initialize (project);
		
		var hxml = targetDirectory + "/haxe/" + (project.debug ? "debug" : "release") + ".hxml";
		
		PathHelper.mkdir (targetDirectory);
		ProcessHelper.runCommand ("", "haxe", [ hxml ]);
		
		if (useNeko) {
			
			NekoHelper.createExecutable (project.templatePaths, "windows", targetDirectory + "/obj/ApplicationMain.n", executablePath);
			NekoHelper.copyLibraries (project.templatePaths, "windows", applicationDirectory);
			
		} else {
			
			FileHelper.copyFile (targetDirectory + "/obj/ApplicationMain" + (project.debug ? "-debug" : "") + ".exe", executablePath);
			
			var iconPath = PathHelper.combine (applicationDirectory, "icon.ico");
			
			if (IconHelper.createWindowsIcon (project.icons, iconPath)) {
				
				ProcessHelper.runCommand ("", PathHelper.findTemplate (project.templatePaths, "bin/ReplaceVistaIcon.exe"), [ executablePath, iconPath ], true, true);
				
			}
			
		}
		
	}
	
	
	public function clean (project:OpenFLProject):Void {
		
		initialize (project);
		
		if (FileSystem.exists (targetDirectory)) {
			
			PathHelper.removeDirectory (targetDirectory);
			
		}
		
	}
	
	
	public function display (project:OpenFLProject):Void {
		
		initialize (project);
		
		var hxml = PathHelper.findTemplate (project.templatePaths, (useNeko ? "neko" : "cpp") + "/hxml/" + (project.debug ? "debug" : "release") + ".hxml");
		var template = new Template (File.getContent (hxml));
		Sys.println (template.execute (generateContext (project)));
		
	}
	
	
	private function generateContext (project:OpenFLProject):Dynamic {
		
		var context = project.templateContext;
		
		context.NEKO_FILE = targetDirectory + "/obj/ApplicationMain.n";
		context.CPP_DIR = targetDirectory + "/obj";
		context.BUILD_DIR = project.app.path + "/windows";
		
		return context;
		
	}
	
	
	private function initialize (project:OpenFLProject):Void {
		
		targetDirectory = project.app.path + "/windows/cpp";
		
		if (project.targetFlags.exists ("neko") || project.target != PlatformHelper.hostPlatform) {
			
			targetDirectory = project.app.path + "/windows/neko";
			useNeko = true;
			
		}
		
		applicationDirectory = targetDirectory + "/bin/";
		executablePath = applicationDirectory + "/" + project.app.file + ".exe";
		
	}
	
	
	public function run (project:OpenFLProject, arguments:Array <String>):Void {
		
		if (project.target == PlatformHelper.hostPlatform) {
			
			initialize (project);
			ProcessHelper.runCommand (applicationDirectory, Path.withoutDirectory (executablePath), arguments);
			
		}
		
	}
	
	
	public function update (project:OpenFLProject):Void {
		
		project = project.clone ();
		
		if (!project.environment.exists ("SHOW_CONSOLE")) {
			
			project.haxedefs.set ("no_console", 1);
			
		}
		
		if (project.targetFlags.exists ("xml")) {
			
			project.haxeflags.push ("-xml " + targetDirectory + "/types.xml");
			
		}
		
		initialize (project);
		
		var context = generateContext (project);
		
		PathHelper.mkdir (targetDirectory);
		PathHelper.mkdir (targetDirectory + "/obj");
		PathHelper.mkdir (targetDirectory + "/haxe");
		PathHelper.mkdir (applicationDirectory);
		
		//SWFHelper.generateSWFClasses (project, targetDirectory + "/haxe");
		
		FileHelper.recursiveCopyTemplate (project.templatePaths, "haxe", targetDirectory + "/haxe", context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, (useNeko ? "neko" : "cpp") + "/hxml", targetDirectory + "/haxe", context);
		
		for (dependency in project.dependencies) {
			
			if (StringTools.endsWith (dependency.path, ".dll")) {
				
				var fileName = Path.withoutDirectory (dependency.path);
				FileHelper.copyIfNewer (dependency.path, applicationDirectory + "/" + fileName);
				
			}
			
		}
		
		for (ndll in project.ndlls) {
			
			FileHelper.copyLibrary (ndll, "Windows", "", (ndll.haxelib != null && ndll.haxelib.name == "hxcpp") ? ".dll" : ".ndll", applicationDirectory, project.debug);
			
		}
		
		/*if (IconHelper.createIcon (project.icons, 32, 32, PathHelper.combine (applicationDirectory, "icon.png"))) {
			
			context.HAS_ICON = true;
			context.WIN_ICON = "icon.png";
			
		}*/
		
		for (asset in project.assets) {
			
			var path = PathHelper.combine (applicationDirectory, asset.targetPath);
			
			if (asset.type != AssetType.TEMPLATE) {
				
				PathHelper.mkdir (Path.directory (path));
				FileHelper.copyAssetIfNewer (asset, path);
				
			} else {
				
				PathHelper.mkdir (Path.directory (path));
				FileHelper.copyAsset (asset, path, context);
				
			}
			
		}
		
		AssetHelper.createManifest (project, PathHelper.combine (applicationDirectory, "manifest"));
		
	}
	
	
	public function new () {}
	@ignore public function install (project:OpenFLProject):Void {}
	@ignore public function trace (project:OpenFLProject):Void {}
	@ignore public function uninstall (project:OpenFLProject):Void {}
	
	
}