package ru.appsm.curl;

/**
 * Created by mnill on 25.08.15.
 */

public class Result {
    byte [] content;
    int headersLength;

    public Result(byte [] content, int headerLength) {
        this.content = content;
        this.headersLength = headerLength;
    }
}
