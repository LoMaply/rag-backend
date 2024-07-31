Class Rag.impl Extends %REST.Impl
{

ClassMethod GetUploads() As %Status
{
    set sqlquery = "SELECT DISTINCT $PIECE($PIECE(metadata, '{""source"": ""C:\\InterSystems\\QS\\mgr\\InternProject\\', 2), '""', 1)FROM EXTRADATA"
    #Dim tRows As %DynamicArray = []

    set tStatement = ##class(%SQL.Statement).%New()
    set qStatus = tStatement.%Prepare(sqlquery)

    if qStatus'=1 {do tRows.%ToJSON() quit}
    set rset = tStatement.%Execute()
    if (rset.%SQLCODE '= 0) {write "%Execute failed:", !, "SQLCODE ", rset.%SQLCODE, ": ", rset.%Message quit}

    while (rset.%Next()) {
        do tRows.%Push(rset.%GetData(1))
    }
    do tRows.%ToJSON()

    Return
}

ClassMethod UploadFile(filename As %String) As %Status [ Language = python ]
{
    #irispip install the following: langchain-cohere, langchain-community, langchain-iris, pypdf, unstructured, sqlalchemy-iris
    import os
    from langchain_cohere import CohereEmbeddings
    from langchain_community.document_loaders import TextLoader, PyPDFLoader, UnstructuredHTMLLoader
    from langchain_community.vectorstores.utils import filter_complex_metadata
    from langchain_iris import IRISVector
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    os.environ["COHERE_API_KEY"] = "IbPD8xoJtRLTVGOhRxlgKAjteoZogCmEFsWXhj6Q"
    CONNECTION_STRING = "iris://superuser:sys@localhost:1972/INTERNPROJECT"
    COLLECTION_NAME = "EXTRADATA"

    embeddings = CohereEmbeddings()

    if (filename.lower().endswith(".pdf")):
        raw_file = PyPDFLoader(filename).load()
    elif (filename.lower().endswith(".txt")):
        raw_file = TextLoader(filename).load()
    elif (filename.lower().endswith(".html")):
        raw_file = UnstructuredHTMLLoader(filename).load()
    else:
        raise Exception(f"Unknown file type")

    text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=200, length_function=len)
    docs = text_splitter.split_documents(raw_file)
    docs = filter_complex_metadata(docs)
    vector_db = IRISVector.from_documents(
        embedding=embeddings,
        documents=docs,
        collection_name=COLLECTION_NAME,
        connection_string=CONNECTION_STRING
    )
    return
}

ClassMethod MakeQuery(query As %String) As %Status [ Language = python ]
{
    # irispip install the following: langchain, langchain-core, langchain-iris, sqlalchemy-iris
    import os
    import json
    from langchain.chains import create_retrieval_chain
    from langchain.chains.combine_documents import create_stuff_documents_chain

    from langchain_cohere import ChatCohere, CohereEmbeddings
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_iris import IRISVector

    ### Model ###
    os.environ["COHERE_API_KEY"] = "IbPD8xoJtRLTVGOhRxlgKAjteoZogCmEFsWXhj6Q"
    CONNECTION_STRING = "iris://superuser:sys@localhost:1972/INTERNPROJECT"
    COLLECTION_NAME = "EXTRADATA"

    llm = ChatCohere(model="command-r",cohere_api_key="IbPD8xoJtRLTVGOhRxlgKAjteoZogCmEFsWXhj6Q")
    embeddings = CohereEmbeddings()

    ### Iris connection ###
    vector_db = IRISVector(
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
        connection_string=CONNECTION_STRING
    )
    retriever = vector_db.as_retriever(search_type="similarity", search_kwargs={"k": 8})

    ### Answer qns ###
    system_prompt = (
        "You are an assistant for question-answering tasks. "
        "Use the following pieces of retrieved context to answer "
        "the question. If you don't know the answer, say that you "
        "don't know. There is no limit on answer length but try to keep it concise."
        "\n\n"
        "{context}"
    )

    prompt = ChatPromptTemplate.from_messages(
        [
            ("system", system_prompt),
            ("human", "{input}"),
        ]
    )

    question_answer_chain = create_stuff_documents_chain(llm, prompt)
    rag_chain = create_retrieval_chain(retriever, question_answer_chain)

    result = {
        "result": rag_chain.invoke({"input": query})["answer"]
    }
    print(json.dumps(result))
    return
}

// Delete all vectors from db

ClassMethod PurgeDB() As %Status
{
    set sqlquery = "DROP TABLE EXTRADATA"

    set tStatement = ##class(%SQL.Statement).%New()
    set qStatus = tStatement.%Prepare(sqlquery)
    if qStatus'=1 {write "%Prepare failed:" do $System.Status.DisplayError(qStatus) quit}
    set rset = tStatement.%Execute()
    if (rset.%SQLCODE '= 0) {write "%Execute failed:", !, "SQLCODE ", rset.%SQLCODE, ": ", rset.%Message quit}

    write !,"Table dropped"

    Return
}

ClassMethod DeleteFile(fileName As %String) As %Status
{
    set sqlquery = "DELETE FROM EXTRADATA WHERE $FIND(metadata,'"_fileName_"') > 0"
    write sqlquery,!
 
    set tStatement = ##class(%SQL.Statement).%New()
    set qStatus = tStatement.%Prepare(sqlquery)
    if qStatus'=1 {write "%Prepare failed:" do $System.Status.DisplayError(qStatus) quit}
    set rset = tStatement.%Execute()
    if (rset.%SQLCODE '= 100 && rset.%SQLCODE '= 0) {write "%Execute failed:", !, "SQLCODE ", rset.%SQLCODE, ": ", rset.%Message quit}
   
    Return
}

}
