// SPDX-License-Identifier: Apache-2.0
package dev.varco;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
class VarcoApplicationTests {

    @Test
    void contextLoads() {}
}
