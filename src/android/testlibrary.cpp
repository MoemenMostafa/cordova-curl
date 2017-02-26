#include "testlibrary.h"

#include <curl/curl.h>

#ifdef ANDROID
	#include <android/log.h>
	#include <jni.h>
	#ifdef __LP64__
		#define SIZE_T_TYPE "%lu"
	#else
		#define SIZE_T_TYPE "%u"
	#endif	
#endif

#ifdef ANDROID
	#define LOGI(...) ((void)__android_log_print(ANDROID_LOG_INFO, "testlibrary", __VA_ARGS__))
#else
	#define LOGI(...) printf(__VA_ARGS__)
#endif

size_t curlCallback(char *data, size_t size, size_t count, void* userdata);

BOOL downloadUrl(const char* url, struct curl_slist* list, bool isPost, const char* postCharData, bool forward, long* header_size, const char* cookieFile, LPCURL_DOWNLOAD_OBJECT downloadObject ) {
	CURL* curl = curl_easy_init();

	curl_easy_setopt(curl, CURLOPT_URL, url);

//	curl_easy_setopt(curl, CURLOPT_PROXY, "10.0.0.30");
//	curl_easy_setopt(curl, CURLOPT_PROXYPORT, 8888);

	curl_easy_setopt(curl, CURLOPT_HTTPHEADER, list);


	if (isPost)
		curl_easy_setopt(curl, CURLOPT_POSTFIELDS, postCharData);

	curl_easy_setopt(curl, CURLOPT_COOKIEFILE, cookieFile);
	curl_easy_setopt(curl, CURLOPT_COOKIEJAR, cookieFile);

	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, forward);
	//curl_easy_setopt(curl, CURLOPT_FAILONERROR, TRUE);

	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, &curlCallback);
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, downloadObject);

	curl_easy_setopt(curl, CURLOPT_HEADER, 1);

	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, FALSE);
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, FALSE);

	CURLcode res = curl_easy_perform(curl);

	if (res != CURLE_OK){
	    LOGI("failed with error code %d", res);
	}
	curl_easy_getinfo(curl, CURLINFO_HEADER_SIZE, header_size);
	curl_easy_cleanup(curl);
	return res == CURLE_OK;
}

size_t curlCallback(char *data, size_t size, size_t count, void* userdata) {
//	LOGI("Downloaded data size is " SIZE_T_TYPE, size*count);

    LPCURL_DOWNLOAD_OBJECT downloadObject = (LPCURL_DOWNLOAD_OBJECT) userdata;
    long newSize = 0;
    long offset = 0;
    LPBYTE dataPtr;

    if (downloadObject->data == NULL){
        newSize = size * count * sizeof(BYTE);
        dataPtr = (LPBYTE)malloc(newSize);
    }else{
        newSize = downloadObject->size + (size * count * sizeof(BYTE));
        dataPtr = (LPBYTE)realloc(downloadObject->data, newSize);
        offset = downloadObject->size;
    }

    if (dataPtr==NULL){//malloc or realloc failed
        if (downloadObject->data != NULL){//realloc failed
            free(downloadObject->data);
            downloadObject->data = NULL;
            downloadObject->size = 0;
        }

        return 0; //this will abort the download
    }
    downloadObject->data = dataPtr;
    downloadObject->size = newSize;

    memcpy(downloadObject->data + offset, data, size * count * sizeof(BYTE));
	return size*count;
}

#ifdef ANDROID
extern "C"
{
	JNIEXPORT jobject JNICALL
	Java_ru_appsm_curl_CordovaWrapper_downloadUrl(JNIEnv* env, jobject obj, jstring url, jobjectArray headers, jint isPost, jstring postData, jint forward, jstring cookie) {
        
		const char* url_c = env->GetStringUTFChars(url, NULL);
		const char* cookie_c = env->GetStringUTFChars(cookie, NULL);

		const int headers_len = env->GetArrayLength(headers);

		bool forwardLocation = false;
        bool isPostC = FALSE;
        
        if (isPost == 1) {
            isPostC = TRUE;
        }

        if (forward == 1) {
            forwardLocation = TRUE;
        }

		jboolean isCopy;
        const char* postCharData = env->GetStringUTFChars(postData, 0);
        
        
//		if(isCopy)
//		{
//		   env->ReleaseByteArrayElements(postData, (jbyte*)postCharData, JNI_ABORT);
//		}

        LOGI("postCharData %s", postCharData);

		struct curl_slist *list = NULL;

		for(int i=0; i<headers_len; ++i) {
            jstring string = (jstring) env->GetObjectArrayElement(headers, i);
//            LOGI("Header %s", env->GetStringUTFChars(string, 0));
            list = curl_slist_append(list, env->GetStringUTFChars(string, 0));
        }

		if (!url_c)
			return NULL;

		CURL_DOWNLOAD_OBJECT* downloadObject = new CURL_DOWNLOAD_OBJECT;

        downloadObject->data = NULL;
        downloadObject->size=0;

		long headersize = 0;
		if (downloadUrl(url_c, list, isPostC, postCharData, forwardLocation, &headersize, cookie_c, downloadObject)) {

			env->ReleaseStringUTFChars(url, url_c);
			env->ReleaseStringUTFChars(cookie, cookie_c);

			jbyteArray ret = env->NewByteArray(downloadObject->size);

			env->SetByteArrayRegion(ret, 0, downloadObject->size, (jbyte*)downloadObject->data);

			jclass cls = env->FindClass("ru/appsm/curl/Result");
         	jmethodID methodId = env->GetMethodID(cls, "<init>", "([BI)V");
         	jobject obj = env->NewObject(cls, methodId, ret, headersize);

			free(downloadObject->data);
			delete downloadObject;

			return obj;
		} else {
			env->ReleaseStringUTFChars(url, url_c);
			return NULL;
		}
	}
}
#endif
