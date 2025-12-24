package com.example.nifi.processors;

import org.apache.nifi.util.MockFlowFile;
import org.apache.nifi.util.TestRunner;
import org.apache.nifi.util.TestRunners;
import org.junit.Before;
import org.junit.Test;

import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class HelloWorldProcessorTest {

    private TestRunner testRunner;

    @Before
    public void init() {
        testRunner = TestRunners.newTestRunner(HelloWorldProcessor.class);
    }

    @Test
    public void testProcessorWithDefaultMessage() {
        testRunner.enqueue(new byte[]{});
        testRunner.run();

        testRunner.assertQueueEmpty();
        List<MockFlowFile> results = testRunner.getFlowFilesForRelationship(HelloWorldProcessor.REL_SUCCESS);
        assertEquals(1, results.size());

        MockFlowFile result = results.get(0);
        result.assertContentEquals("Hello, NiFi!");
        result.assertAttributeEquals("custom.processor", "HelloWorldProcessor");
    }

    @Test
    public void testProcessorWithCustomMessage() {
        testRunner.setProperty(HelloWorldProcessor.MESSAGE, "Custom Test Message");
        testRunner.enqueue(new byte[]{});
        testRunner.run();

        testRunner.assertQueueEmpty();
        List<MockFlowFile> results = testRunner.getFlowFilesForRelationship(HelloWorldProcessor.REL_SUCCESS);
        assertEquals(1, results.size());

        MockFlowFile result = results.get(0);
        result.assertContentEquals("Custom Test Message");
        result.assertAttributeEquals("custom.message", "Custom Test Message");
    }

    @Test
    public void testValidation() {
        testRunner.setProperty(HelloWorldProcessor.MESSAGE, "");
        testRunner.assertNotValid();

        testRunner.setProperty(HelloWorldProcessor.MESSAGE, "Valid Message");
        testRunner.assertValid();
    }
}