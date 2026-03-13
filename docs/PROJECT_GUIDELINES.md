---



\# Analytics Workbench



\## Project Operating Instructions



These instructions define the documentation, coding, and development standards used throughout the \*\*Analytics Workbench\*\* project.



All future development threads should follow these guidelines unless explicitly revised.



The goal is to ensure the project remains:



• understandable

• maintainable

• transparent

• portable across development sessions



Even when code is produced collaboratively with AI.



---



\# 1. Project Philosophy



Analytics Workbench is designed as an:



\*\*AI-assisted analytics environment\*\*



Not an autonomous AI system.



The system should always maintain:



• human visibility into logic

• human control over execution

• editable SQL workflows

• transparent transformations

• predictable behavior



AI assists the user but \*\*does not replace human judgment.\*\*



---



\# 2. Code Documentation Standard



All significant software files should include \*\*clear documentation and explanatory comments.\*\*



The codebase should prioritize \*\*readability and maintainability over minimalism.\*\*



When rewriting or creating files, avoid providing raw code without explanation.



---



\# 3. Required File Header Structure



Every major file should begin with a clear documentation header explaining the role of the file.



Example structure:



```

File: main.py



Purpose

-------

Primary FastAPI application for Analytics Workbench.



Responsibilities

---------------

• dataset registration

• SQL execution

• export endpoints

• API routing



Execution Flow

--------------

Request → validation → dataset resolution → SQL execution → result formatting → response



Important Notes

---------------

• /api/sql returns preview rows only

• /api/sql/export returns full result sets

• dataset references in SQL are rewritten internally



Related Components

------------------

Frontend: index.html

Services: dataset\_import.py, chart\_recommender.py

```



Headers should be written in \*\*plain language\*\*, not just technical shorthand.



---



\# 4. Commenting Standard



Comments should explain:



• what the code does

• why it does it

• what assumptions it relies on

• what could break if modified incorrectly



Focus on \*\*logic explanation\*\*, not just syntax.



Example:



```

\# Rewrite logical dataset reference so users can write:

\#     SELECT \* FROM dataset

\#

\# Internally we replace this with the actual parquet reader path.

\# This keeps SQL queries readable while still executing against the

\# correct physical dataset file.

```



Avoid:



• sparse commenting

• undocumented shortcuts

• unclear helper functions



---



\# 5. Code Structure Guidelines



Prefer clear logical structure over compressed code.



Large functions should be organized into clearly labeled stages.



Example pipeline structure:



```

1\. Validate request

2\. Normalize input

3\. Resolve dataset source

4\. Rewrite SQL dataset references

5\. Execute query

6\. Build preview response

7\. Log audit event

8\. Return response

```



This structure helps future readers quickly understand system behavior.



---



\# 6. Backend Development Guidelines



Backend code should clearly document:



• endpoint purpose

• request payload structure

• response structure

• validation rules

• dataset handling logic

• preview vs export behavior

• error handling strategy



Important distinctions must always be explicit.



Example:



```

/api/sql

Preview endpoint.

Returns up to MAX\_PREVIEW\_ROWS rows for fast UI interaction.



/api/sql/export

Full execution endpoint.

Returns the complete dataset result for download.

```



---



\# 7. Frontend Development Guidelines



Frontend code should clearly explain:



• UI layout sections

• workflow order

• button behavior

• API interactions

• state management

• preview vs export logic

• rendering decisions



UI logic should remain transparent and easy to follow.



Example:



```

\# Preview tables intentionally limit rows to 200 for performance.

\# Export buttons request the full dataset from the backend export endpoint.

```



---



\# 8. File Modification Standards



When making code changes, prefer:



\### Best approach



Provide the \*\*entire updated file\*\* when the modification is broad.



\### Acceptable alternative



Provide \*\*precise replacement sections\*\* when the change is localized.



Changes should always be presented in a \*\*clean, copy-safe format\*\*.



---



\# 9. Debugging Guidelines



When diagnosing issues:



1\. Identify the \*\*root cause\*\*, not just symptoms

2\. Separate \*\*frontend issues from backend issues\*\*

3\. Distinguish \*\*preview behavior from export behavior\*\*

4\. Reference the specific function or line causing the issue



Solutions should clearly explain \*\*what changed and why.\*\*



---



\# 10. Milestone Documentation Standard



Milestone planning documents should include:



• milestone objective

• strategic purpose

• scope

• confirmed product decisions

• implementation plan

• acceptance criteria

• definition of done



Milestone documentation should be written so it can be pasted into a new thread and remain understandable.



---



\# 11. Cross-Thread Consistency Rule



These standards should continue across all future Analytics Workbench development threads.



This ensures:



• consistent documentation

• consistent coding style

• predictable architecture decisions

• easier future maintenance



Unless explicitly changed, assume these standards remain in effect.



---



\# 12. Development Priority



Throughout the project, prioritize:



1\. clarity

2\. stability

3\. explainability

4\. maintainability



over:



• clever code

• compressed logic

• undocumented behavior



The system should always be understandable by someone reviewing the project later.



---



\# Recommended Usage



At the beginning of future development threads, include the following note:



```

This thread follows the Analytics Workbench Project Operating Instructions.

All code should include clear headers, explanatory comments, and structured logic

consistent with the established project documentation standard.

```



---



If you'd like, I can also generate a \*\*very short 8-line “Thread Bootstrap” version\*\* of this that works even better at the top of every development thread.



