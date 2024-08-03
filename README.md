IRIS backend + db for RAG chatbot. Requires InterSystems IRIS. Used in tandem with [rag-frontend](https://github.com/LoMaply/rag-frontend).

Before running, use irispip to install the following:

- langchain
- langchain-cohere
- langchain-community
- langchain-core
- langchain-iris
- pypdf
- unstructured
- sqlalchemy-iris

Web application must be configured in InterSystems IRIS using Rag.disp as the dispatch class. InternProject namespace is used in the code, remember to update the file path in the GetUploads() method of Rag.impl and the connection string in the UploadFile() and MakeQuery() methods if the namespace is to be changed.

A free trial API key for Cohere is used.
