package com.example.nifi.processors;

import org.apache.nifi.annotation.behavior.InputRequirement;
import org.apache.nifi.annotation.behavior.SideEffectFree;
import org.apache.nifi.annotation.documentation.CapabilityDescription;
import org.apache.nifi.annotation.documentation.Tags;
import org.apache.nifi.components.PropertyDescriptor;
import org.apache.nifi.flowfile.FlowFile;
import org.apache.nifi.processor.AbstractProcessor;
import org.apache.nifi.processor.ProcessContext;
import org.apache.nifi.processor.ProcessSession;
import org.apache.nifi.processor.ProcessorInitializationContext;
import org.apache.nifi.processor.Relationship;
import org.apache.nifi.processor.exception.ProcessException;
import org.apache.nifi.processor.util.StandardValidators;

import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Tags({"example", "hello", "custom"})
@CapabilityDescription("A simple example processor that adds a custom message to FlowFile content")
@SideEffectFree
@InputRequirement(InputRequirement.Requirement.INPUT_ALLOWED)
public class HelloWorldProcessor extends AbstractProcessor {

    public static final PropertyDescriptor MESSAGE = new PropertyDescriptor.Builder()
            .name("Message")
            .displayName("Message")
            .description("The message to add to FlowFile content")
            .required(true)
            .defaultValue("Hello, NiFi!")
            .addValidator(StandardValidators.NON_EMPTY_VALIDATOR)
            .build();

    public static final Relationship REL_SUCCESS = new Relationship.Builder()
            .name("success")
            .description("FlowFiles that are successfully processed")
            .build();

    public static final Relationship REL_FAILURE = new Relationship.Builder()
            .name("failure")
            .description("FlowFiles that failed to process")
            .build();

    private List<PropertyDescriptor> descriptors;
    private Set<Relationship> relationships;

    @Override
    protected void init(final ProcessorInitializationContext context) {
        final List<PropertyDescriptor> descriptors = new ArrayList<>();
        descriptors.add(MESSAGE);
        this.descriptors = Collections.unmodifiableList(descriptors);

        final Set<Relationship> relationships = new HashSet<>();
        relationships.add(REL_SUCCESS);
        relationships.add(REL_FAILURE);
        this.relationships = Collections.unmodifiableSet(relationships);
    }

    @Override
    public Set<Relationship> getRelationships() {
        return this.relationships;
    }

    @Override
    public final List<PropertyDescriptor> getSupportedPropertyDescriptors() {
        return descriptors;
    }

    @Override
    public void onTrigger(final ProcessContext context, final ProcessSession session) throws ProcessException {
        FlowFile flowFile = session.get();
        if (flowFile == null) {
            flowFile = session.create();
        }

        try {
            final String message = context.getProperty(MESSAGE).getValue();

            flowFile = session.write(flowFile, (OutputStream out) -> {
                out.write(message.getBytes());
            });

            flowFile = session.putAttribute(flowFile, "custom.processor", "HelloWorldProcessor");
            flowFile = session.putAttribute(flowFile, "custom.message", message);

            session.transfer(flowFile, REL_SUCCESS);
            getLogger().info("Successfully processed FlowFile with message: {}", message);

        } catch (Exception e) {
            getLogger().error("Failed to process FlowFile", e);
            session.transfer(flowFile, REL_FAILURE);
        }
    }
}