       PROCESS NODYNAM,RENT,APOST,CICS,TRUNC(OPT)
      *----------------------------------------------------------------*
      *  Licensed Materials - Property of IBM                          *
      *  SAMPLE                                                        *
      *  (c) Copyright IBM Corp. 2019 All Rights Reserved              *
      *  US Government Users Restricted Rights - Use, duplication or   *
      *  disclosure restricted by GSA ADP Schedule Contract with       *
      *  IBM Corp                                                      *
      *----------------------------------------------------------------*
      ******************************************************************
      *                                                                *
      * Module Name  WLPCTRLW.CBL                                      *
      *                                                                *
      * Liberty HTTP Controller Wrapper sample                         *
      *                                                                *
      * This program expects to be called by a terminal (TD) or by an  *
      * Event Processing adapter (S). It can receive two parameters.   *
      * The first parameter is the operation on the HTTP endpoint, and *
      * is mandatory. The value is either 'RESUME' or 'PAUSE' (case-se *
      * nsitive).                                                      *
      * The second parameter is the ID of the HTTP endpoint (case-sens *
      * itive). If the program is invoked with a terminal the second   *
      * parameter is optional, the default value defaultHttpEndpoint   *
      * is used.                                                       *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.              WLPCTRLW.
      *
       ENVIRONMENT DIVISION.
      *
       DATA DIVISION.
      *
       WORKING-STORAGE SECTION.
      *
      *   Working storage definitions
       01 WS-STORAGE.
          03 WS-TERMINAL-INPUT-NUM PIC 9(02)         VALUE ZERO.
          03 WS-TERMINAL-INPUT     PIC X(40)         VALUE SPACES.
          03 WS-START-CODE         PIC XX            VALUE SPACES.
          03 WS-TRANSID            PIC X(4)          VALUE SPACES.
          03 WS-LENGTH             PIC 9(4)  COMP    VALUE ZERO.
          03 WS-RESP               PIC S9(8) COMP    VALUE ZERO.
          03 WS-RESP2              PIC S9(8) COMP    VALUE ZERO.
          03 PGM-ERROR-COUNT       PIC 9     COMP    VALUE ZERO.
          03 ABSTIME               PIC S9(15) COMP-3 VALUE ZERO.


      *
      *  Begin: parameters that can be customized
          03 PGM-ERROR-COUNT-MAX   PIC 9     COMP    VALUE 3.
          03 SLEEP-TIME-SEC        PIC S9(8) BINARY  VALUE 15.
      *  End: parameters that can be customized
      *

      *  Return code and associated messages
          03 WS-RETURN-CODE        PIC 9     COMP    VALUE 9.
             88 SUCCESS                     VALUE 0.
             88 TERMINAL-INPUT-LENGERR      VALUE 1.
             88 TERMINAL-INPUT-NUMERR       VALUE 2.
             88 OPERERR                     VALUE 3.
             88 LINKERR                     VALUE 4.
             88 JAVAERR                     VALUE 5.
             88 START-INFO                  VALUE 9.

      *  Response header is only used when printing to MSGUSR
       01 RESPONSE-MSG.
          03 RESPONSE-HEADER      PIC X(10)     VALUE 'WLPCTRLW  '.
          03 DATE-AREA            PIC X(10).
          03 DATE-FILLER1         PIC X(1)      VALUE SPACE.
          03 TIME-AREA            PIC X(8).
          03 DATE-FILLER2         PIC X(1)      VALUE SPACE.
          03 RESPONSE-BODY        PIC X(256)    VALUE SPACES.
       01 USER-MSG-START          PIC X(22)
           VALUE 'BEGIN RUNNING WLPCTRLW'.
       01 USER-MSG-PAUSE          PIC X(36)
           VALUE 'LIBERTY HTTPENDPOINT HAS BEEN PAUSED'.
       01 USER-MSG-RESUME         PIC X(37)
           VALUE 'LIBERTY HTTPENDPOINT HAS BEEN RESUMED'.
       01 ERROR-LENGERR-MSG       PIC X(43)
           VALUE 'ERROR: INPUT PARAMETERS LENGTH IS INCORRECT'.
       01 ERROR-NUMERR-MSG        PIC X(43)
           VALUE 'ERROR: NUMBER OF INPUT PARAMETERS IS 1 or 2'.
       01 ERROR-OPERERR-MSG       PIC X(50)
           VALUE 'ERROR: 1st PARAMETER SHOULD BE "RESUME" OR "PAUSE"'.
       01 ERROR-LINKERR-MSG.
          03 FILLER               PIC X(17) VALUE 'ERROR LINKING TO '.
          03 ERROR-PROG           PIC X(8).
          03 FILLER               PIC X(7)  VALUE '- RESP:'.
          03 ERROR-RESP           PIC 9(8) DISPLAY.
          03 FILLER               PIC X(7) VALUE ' RESP2:'.
          03 ERROR-RESP2          PIC 9(8) DISPLAY.


      *   Container sent to Liberty
       01 WLPDATA.
          03 RULE-OPERATION        PIC X(10)         VALUE SPACES.
             88 RULE-OPERATION-RESUME                VALUE 'RESUME'.
             88 RULE-OPERATION-PAUSE                 VALUE 'PAUSE'.
          03 RULE-ENDPOINT         PIC X(128)        VALUE SPACES.

      *   Container received from Liberty
       01 WLPRESP.
          03 WLP-RETURN-CODE       PIC 9(2).
          03 WLP-ERROR-MSG         PIC X(256)        VALUE SPACES.
          03 WLP-ERROR-MSG-LEN     PIC 9(4) COMP.
       01 WLPRESP-LEN              PIC S9(8) COMP.

       77 WLP-CHANNEL               PIC X(16) VALUE 'DFHTRANSACTION'.
       77 WLP-INPUT-CONTAINER-NAME  PIC X(16) VALUE 'WLPDATA'.
       77 WLP-OUTPUT-CONTAINER-NAME PIC X(16) VALUE 'WLPRESP'.
       77 WLP-CONTROL-PROGRAM       PIC X(8)  VALUE 'WLPCTRL'.
      *
      *
       PROCEDURE DIVISION.
      *
       MAIN-PROCESSING SECTION.
      *    Determine if the program is started by a terminal (TD)
      *    or a policy (S)
           EXEC CICS ASSIGN STARTCODE(WS-START-CODE)
             RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.

      *    Only print START information when not invoked by terminal
      *    otherwise the user input is flushed since the program 
      *    does not save it.
           IF WS-START-CODE EQUAL 'S' THEN
             PERFORM PRINT-MESSAGE
           END-IF

           PERFORM GET-INPUT.
           PERFORM LINK-TO-LIBERTY UNTIL WS-RETURN-CODE < 9
           PERFORM PRINT-MESSAGE.

      *    Return control to CICS (end transaction).
           EXEC CICS RETURN END-EXEC.
      *
           GOBACK.


       GET-INPUT.
      *    If started with terminal
           IF WS-START-CODE EQUAL 'TD' THEN
      *    Receive data from terminal, only 40 first characters
             MOVE LENGTH OF WS-TERMINAL-INPUT TO WS-LENGTH
             EXEC CICS RECEIVE INTO(WS-TERMINAL-INPUT)
               LENGTH(WS-LENGTH)
             END-EXEC

      *    Parse the input into operation and HTTP endpoint ID
             INITIALIZE WS-TERMINAL-INPUT-NUM
             UNSTRING WS-TERMINAL-INPUT DELIMITED BY ALL SPACES
               INTO WS-TRANSID, RULE-OPERATION, RULE-ENDPOINT
               TALLYING WS-TERMINAL-INPUT-NUM
               ON OVERFLOW
                 MOVE 1 TO WS-RETURN-CODE
                 PERFORM PRINT-MESSAGE
                 EXEC CICS RETURN END-EXEC
             END-UNSTRING

      *    Check the number of inputs, complete if necessary
             IF WS-TERMINAL-INPUT-NUM EQUAL 2 THEN
                 MOVE 'defaultHttpEndpoint' TO RULE-ENDPOINT
             ELSE IF WS-TERMINAL-INPUT-NUM NOT EQUAL 3 THEN
                 MOVE 2 TO WS-RETURN-CODE
                 PERFORM PRINT-MESSAGE
                 EXEC CICS RETURN END-EXEC
             END-IF

      *    Otherwise assume the program is started by a policy
           ELSE
      *    Get first user static data (cf. check rule definition)
               EXEC CICS GET CONTAINER('DFHEP.DATA.00030')
                 INTO(RULE-OPERATION) RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC

      *    Get second user static data (cf. check rule definition)
               EXEC CICS GET CONTAINER('DFHEP.DATA.00031')
                 INTO(RULE-ENDPOINT) RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
           END-IF.

      *    Check if the operation is supported
           IF NOT RULE-OPERATION-PAUSE
            AND NOT RULE-OPERATION-RESUME THEN
               MOVE 3 TO WS-RETURN-CODE
               PERFORM PRINT-MESSAGE
               EXEC CICS RETURN END-EXEC
           END-IF
           EXIT.


       LINK-TO-LIBERTY.
           EXEC CICS PUT CONTAINER(WLP-INPUT-CONTAINER-NAME)
             CHANNEL(WLP-CHANNEL) FROM(WLPDATA)
           END-EXEC

           EXEC CICS LINK PROGRAM(WLP-CONTROL-PROGRAM)
             CHANNEL(WLP-CHANNEL)
             RESP(ERROR-RESP) RESP2(ERROR-RESP2)
           END-EXEC.

      *    Perform basic response checking from LINK, report error.
           IF ERROR-RESP NOT EQUAL DFHRESP(NORMAL) THEN
      *    The Liberty server may take a few seconds to be
      *    ready and "linkable". Retry after a delay.
              ADD 1 TO PGM-ERROR-COUNT
              IF PGM-ERROR-COUNT < PGM-ERROR-COUNT-MAX THEN
                 EXEC CICS DELAY FOR SECONDS(SLEEP-TIME-SEC)
                 END-EXEC
              ELSE
      *    Maximum number of tries reached
                 MOVE WLP-CONTROL-PROGRAM TO ERROR-PROG
                 MOVE 4 TO WS-RETURN-CODE
              END-IF
           ELSE
      *    Successfully linked to Liberty
              MOVE LENGTH OF WLPRESP TO WLPRESP-LEN
              EXEC CICS GET CONTAINER(WLP-OUTPUT-CONTAINER-NAME)
                CHANNEL(WLP-CHANNEL) INTO(WLPRESP)
              END-EXEC
      *    Check Java program return code
              IF WLP-RETURN-CODE EQUAL 0 THEN
                  MOVE 0 TO WS-RETURN-CODE
              ELSE
                  MOVE 5 TO WS-RETURN-CODE
           END-IF.
           EXIT.


       PRINT-MESSAGE.
           EVALUATE TRUE
               WHEN START-INFO
                       MOVE LENGTH OF USER-MSG-START TO WS-LENGTH
                       MOVE USER-MSG-START TO RESPONSE-BODY
               WHEN SUCCESS
                       IF RULE-OPERATION-RESUME THEN
                           MOVE LENGTH OF USER-MSG-RESUME TO WS-LENGTH
                           MOVE USER-MSG-RESUME TO RESPONSE-BODY
                       ELSE
                           MOVE LENGTH OF USER-MSG-PAUSE TO WS-LENGTH
                           MOVE USER-MSG-PAUSE TO RESPONSE-BODY
                       END-IF
               WHEN TERMINAL-INPUT-LENGERR
                       MOVE LENGTH OF ERROR-LENGERR-MSG TO WS-LENGTH
                       MOVE ERROR-LENGERR-MSG TO RESPONSE-BODY
               WHEN TERMINAL-INPUT-NUMERR
                       MOVE LENGTH OF ERROR-NUMERR-MSG TO WS-LENGTH
                       MOVE ERROR-NUMERR-MSG TO RESPONSE-BODY
               WHEN OPERERR
                       MOVE LENGTH OF ERROR-OPERERR-MSG TO WS-LENGTH
                       MOVE ERROR-OPERERR-MSG TO RESPONSE-BODY
               WHEN LINKERR
                       MOVE LENGTH OF ERROR-LINKERR-MSG TO WS-LENGTH
                       MOVE ERROR-LINKERR-MSG TO RESPONSE-BODY
               WHEN JAVAERR
                       MOVE WLP-ERROR-MSG-LEN TO WS-LENGTH
                       MOVE WLP-ERROR-MSG TO RESPONSE-BODY
           END-EVALUATE

      *    For terminal users, print response to terminal
           IF WS-START-CODE EQUAL 'TD' THEN
               EXEC CICS SEND TEXT FROM(RESPONSE-BODY)
                 ERASE FREEKB LENGTH(WS-LENGTH)
               END-EXEC
           ELSE
      *    For event processing adapter, print to MSGUSR with header
               ADD LENGTH OF RESPONSE-HEADER TO WS-LENGTH

               EXEC CICS ASKTIME ABSTIME(ABSTIME)
               END-EXEC
               EXEC CICS FORMATTIME
                     ABSTIME(ABSTIME)
                     MMDDYYYY(DATE-AREA)
                     DATESEP('/')
                     TIME(TIME-AREA)
                     TIMESEP(':')
               END-EXEC
               ADD LENGTH OF DATE-AREA TO WS-LENGTH
               ADD LENGTH OF TIME-AREA TO WS-LENGTH
               ADD LENGTH OF DATE-FILLER1 TO WS-LENGTH
               ADD LENGTH OF DATE-FILLER2 TO WS-LENGTH

               EXEC CICS WRITEQ TD QUEUE('CSSL') FROM(RESPONSE-MSG)
                 LENGTH(WS-LENGTH)
               END-EXEC
           END-IF
           EXIT.
