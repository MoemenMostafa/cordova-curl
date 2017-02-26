package ru.appsm.curl;

import java.io.BufferedReader;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import ru.appsm.curl.Result;

public class CordovaWrapper extends CordovaPlugin {
    
    static {
        System.loadLibrary("testlibrary");
    }
    
    private static final String TAG = "Curl";
    
    @Override
    public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {
        
        if (action.equals("query")) {
            final String url = args.getString(0);
            
            final JSONArray headersArray = args.getJSONArray(1);
            final String[] headers = new String[headersArray.length()];
            
            for(int i = 0; i < headersArray.length(); i++) {headers[i] = headersArray.getString(i);}
            String postData = null;
            try {
                postData = args.getString(2);
                if (postData.equals("null"))
                    postData = null;
            } catch (Exception e){postData = null;}
            
            Boolean followLocation;
            try {followLocation = args.getBoolean(3);} catch (Exception e){followLocation = false;}
            
            String cookieName;
            try {cookieName = args.getString(4);} catch (Exception e){cookieName = "cookie";}
            
            final File cacheFile = new File(cordova.getActivity().getFilesDir(), cookieName);
            
            final String fPostData = postData;
            final String emptyByte = "null";
            final Boolean fFollowLocation = followLocation;
            
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    Result content = downloadUrl(url, headers, fPostData != null ? 1 : 0, fPostData != null ? fPostData : emptyByte, fFollowLocation ? 1 : 0, cacheFile.getAbsolutePath());
                    String contentString = content == null ? null : new String(content.content);
                    if (contentString != null) {
                        Log.i(TAG, contentString);
                        JSONArray result = new JSONArray();
                        result.put(contentString.substring(content.headersLength, contentString.length()));
                        result.put(contentString.substring(0, content.headersLength));
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, result));
                    } else {
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR));
                    }
                }
            });
            
        } else if (action.equals("reset")) {
            String cookieName;
            try {cookieName = args.getString(0);} catch (Exception e){cookieName = "cookie";}
            File cacheFile = new File(cordova.getActivity().getFilesDir(), cookieName);
            cacheFile.delete();
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
        } else if (action.equals("cookie")) {
            try {
                String cookieName;
                try {cookieName = args.getString(0);} catch (Exception e){cookieName = "cookie";}
                File cacheFile = new File(cordova.getActivity().getFilesDir(), cookieName);
                String content = getStringFromFile(cacheFile.getAbsolutePath());
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, content));
            } catch (Exception e) {
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR));
            }
        } else {
            return false;
        }
        return true;
    }
    
    public static String getStringFromFile (String filePath) throws Exception {
        File fl = new File(filePath);
        FileInputStream fin = new FileInputStream(fl);
        String ret = convertStreamToString(fin);
        fin.close();
        return ret;
    }
    
    public static String convertStreamToString(InputStream is) throws Exception {
        BufferedReader reader = new BufferedReader(new InputStreamReader(is));
        StringBuilder sb = new StringBuilder();
        String line = null;
        while ((line = reader.readLine()) != null) {
            sb.append(line).append("\n");
        }
        reader.close();
        return sb.toString();
    }
    
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        this.cordova = cordova;
    }
    
    public native Result downloadUrl(String url, String[] headers, int isPost, String postData, int follow, String cacheFile);
}
