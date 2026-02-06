Goal: Verify the tool only allows increasing partitions and reports errors cleanly.

  Pre-reqs:

  - Cluster running
  - TLS client config works

  Steps:

  1. Create a topic with 2 partitions.
      - Prompt: “Create topic alter-test with 2 partitions and RF 3”
  2. Describe the topic to confirm partitions.
      - Prompt: “Describe topic alter-test”
  3. Increase partitions to 4.
      - Prompt: “Increase partitions of alter-test to 4”
  4. Describe again to verify partitions = 4.
      - Prompt: “Describe topic alter-test”
  5. Negative test: attempt to decrease to 2 (should fail).
      - Prompt: “Increase partitions of alter-test to 2”
  6. Clean-up (optional):
      - Prompt: “Delete topic alter-test”

