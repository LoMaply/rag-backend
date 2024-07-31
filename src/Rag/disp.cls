Class Rag.disp Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/upload" Method="GET" Call="GetUploads" />
    <Route Url="/upload" Method="POST" Call="UploadFile"/>
    <Route Url="/query" Method="POST" Call="MakeQuery" />
    <Route Url="/purge" Method="DELETE" Call="PurgeDB" />
    <Route Url="/delete" Method="DELETE" Call="DeleteFile" />
</Routes>
}

ClassMethod OnPreDispatch() As %Status
{
    Do %response.SetHeader("Access-Control-Allow-Credentials","true")
    Do %response.SetHeader("Access-Control-Allow-Methods","GET, PUT, POST, DELETE, OPTIONS")
    Do %response.SetHeader("Access-Control-Max-Age","10000")
    Do %response.SetHeader("Access-Control-Allow-Headers","Content-Type, Authorization, Accept-Language, X-Requested-With")
    quit $$$OK
}

ClassMethod GetUploads() As %Status
{
    set %response.Status=..#HTTP200OK
    set tSC = $$$OK
    do ##class(Rag.impl).GetUploads()

    return tSC
}

ClassMethod UploadFile() As %Status
{
    set %response.Timeout = 600
    try {
        set info = {}
        // Save file
        set source = %request.GetMimeData("file")
        set destination = ##class(%Stream.FileBinary).%New()
        set destination.Filename = $PIECE($PIECE(source.Attributes("Headers"), "filename=", 2), """", 2)
        set tSC = destination.CopyFrom(source)
        set result = destination.%Save()

        // Perform upload using file path to save location
        do ##class(Rag.impl).UploadFile(destination.Filename)

        set info.return = result
        set info.message = "File successfully uploaded"
        // Delete file from save location to prevent clog
        do ##class(%File).Delete(destination.Filename)

        write info.%ToJSON()
    } catch e {
        set tSC = e.AsStatus()
        set pOutput = tSC
    }
    return tSC
}

ClassMethod MakeQuery() As %Status
{
    set %response.Status=..#HTTP200OK
    set tSC = $$$OK
 
    // Parse the JSON request body into an object
    set apirequest = {}.%FromJSON(%request.Content)
 
    // Validate required fields
    if '$IsObject(apirequest) || (apirequest.query="") {
        set tSC=$$$ERROR(400,"Invalid request. Missing required fields.")
        set %response.Status=..#HTTP400BADREQUEST
        $$$ThrowStatus(tSC)
    }

    do ##class(Rag.impl).MakeQuery(apirequest.query)

    return tSC
}

ClassMethod PurgeDB() As %Status
{
    set %response.Status=..#HTTP200OK
    set tSC = $$$OK
 
    do ##class(Rag.impl).PurgeDB()

    return tSC
}

ClassMethod DeleteFile() As %Status
{
    set %response.Status=..#HTTP200OK
    set tSC = $$$OK
 
    // Parse the JSON request body into an object
    set apirequest = {}.%FromJSON(%request.Content)
 
    // Validate required fields
    if '$IsObject(apirequest) || (apirequest.fileName="") {
        set tSC=$$$ERROR(400,"Invalid request. Missing required fields.")
        set %response.Status=..#HTTP400BADREQUEST
        $$$ThrowStatus(tSC)
    }
 
    write apirequest.fileName,!
 
    do ##class(Rag.impl).DeleteFile(apirequest.fileName)
 
    return tSC
}

}
