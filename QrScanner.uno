using Fuse;
using Fuse.Reactive;
using Uno.UX;
using Fuse.Scripting;
using Uno.Permissions;
using Uno.Threading;
using Fuse.Platform;
using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Android;


[Require("AndroidManifest.ApplicationElement", "<activity android:name=\"com.cms.farmup.app.ZBarScannerActivity\" android:theme=\"@style/Theme.AppCompat\"></activity>")]
[Require("AndroidManifest.RootElement", "<uses-feature android:name=\"android.hardware.camera\"/>")]
[Require("AndroidManifest.RootElement", "<uses-feature android:name=\"android.hardware.camera.autofocus\"/>")]
[Require("Gradle.Dependency.Compile", "me.dm7.barcodescanner:zbar:1.9")]
[Require("Gradle.Dependency","compile('me.dm7.barcodescanner:zxing:1.9') { exclude module: 'support-v4' }")]
[Require("Gradle.Repository","mavenCentral()")]
[extern(Android) ForeignInclude(Language.Java, "android.content.Intent")]
[extern(Android) ForeignInclude(Language.Java, "android.util.Log")]
[extern(Android) ForeignInclude(Language.Java, "net.sourceforge.zbar.Symbol")]
[extern(Android) ForeignInclude(Language.Java, "com.cms.*")]
[extern(Android) ForeignInclude(Language.Java, "com.fuse.Activity")]
[UXGlobalModule]
public class QrScanner : NativeEventEmitterModule
{
	static readonly QrScanner _instance;
	static string SCAN_RESULT = "SCAN_RESULT";
    static string SCAN_BARCODE_FORMAT = "SCAN_BARCODE_FORMAT";
    static string SCAN_FLASH = "SCAN_FLASH";
    static string SCAN_AUTO_FOCUS = "SCAN_AUTO_FOCUS";
    static string ERROR_INFO = "ERROR_INFO";

    static string CONFIG_FORMAT = "QRCODE";
    static bool CONFIG_FLASH = true;
    static bool CONFIG_AUTOFOCUS = true;

    Fuse.Scripting.Object _resultHolder;

	public QrScanner() : base(true, "QRECEIVED", "QCANCELED", "QERROR", "PermissionReceived", "PermissionDenied")
	{
		if defined(Android)
		{
			Permissions.Request(Permissions.Android.INTERNET).Then(OnPermissionsPermitted,OnPermissionsRejected);
			Permissions.Request(Permissions.Android.CAMERA).Then(OnPermissionsPermitted,OnPermissionsRejected);
		}

		if (_instance != null) return;

		_instance = this;
		Resource.SetGlobalKey(_instance, "QrScanner");
	    AddMember(new NativeFunction("Launch", (NativeCallback)Launch));
	    AddMember(new NativeFunction("Init", (NativeCallback)Init));
	}

	extern(Android) object[]  Launch(Fuse.Scripting.Context c, object[] args){
		debug_log "launching zbarscanner";

		_resultHolder = c.NewObject();
		
		var intent = GetIntent();
        if (intent!=null)
        {
            ActivityUtils.StartActivity(intent, OnResult);
            debug_log "launching ZBARACTIVITY";
        } else {
            Emit("QERROR", "Unable to launch ZBARACTIVITY");
        }
        return null;
	}

	extern(!Android) object Launch(Context c, object[] args){
		debug_log "launching zbarscanner definitely not on android";
		return null;
	}


	object[]  Init(Fuse.Scripting.Context c, object[] args){
		if (args.Length > 0){
			if (args[0] != null){
				CONFIG_FORMAT = (string)args[0];
			}else{
				Emit("QERROR", "CONFIG_FORMAT is null using default");
			}

			if (args[1] != null){
				CONFIG_FLASH = (bool)args[1];
			}else{
				Emit("QERROR", "CONFIG_FLASH is null using default");
			}

			if (args[2] != null){
				CONFIG_AUTOFOCUS = (bool) args[2];
			}else{
				Emit("QERROR", "CONFIG_AUTOFOCUS is null using default");
			}
		}
		return null;
	}


	extern(Android) void OnPermissionsPermitted(PlatformPermission p)
	{
		Emit("PermissionReceived", "Permissions allowed" + p);
	}

	extern(Android) void OnPermissionsRejected(Exception e)
	{
		Emit("PermissionDenied", "PermissionDenied "+ e);
	}

	
	[Foreign(Language.Java)]
	extern (Android)  Java.Object GetIntent()
	@{
		Intent intent = new Intent(Activity.getRootActivity(), ZBarScannerActivity.class);
		intent.putExtra(ZBarScannerActivity.SCAN_AUTO_FOCUS, @{CONFIG_AUTOFOCUS:Get()});
		intent.putExtra(ZBarScannerActivity.SCAN_FLASH, @{CONFIG_FLASH:Get()});
		intent.putExtra(ZBarScannerActivity.SCAN_BARCODE_FORMAT, new int[]{Symbol.QRCODE});
		return intent;
	@}

	[Foreign(Language.Java)]
	 extern(Android) void OnResult(int resultCode, Java.Object intent, object info)
    @{	 
    	//RESULT_CANCELED = 0
    	if (resultCode == 0) {
    		@{QrScanner:Of(_this).resCanceled(string):Call("ZBarActivity Result canceled")};
    		return;
    	}
    	//RESULT_OK = -1
    	if(resultCode < 0){

	    	Intent t = (Intent)intent;
	        @{QrScanner:Of(_this).resSuccess(string, string):Call(
	        	t.getStringExtra(ZBarScannerActivity.SCAN_RESULT), 
	        	t.getStringExtra(ZBarScannerActivity.SCAN_BARCODE_FORMAT)
	        	)};
    	}

    @}

    public void resSuccess(string res, string format)
    {
       	_resultHolder["format"] = format;
    	_resultHolder["result"] = res;
    	Emit("QRECEIVED", _resultHolder);
    }

	public void resCanceled(string res)
	{
		Emit("QCANCELED", "res");
	}
}