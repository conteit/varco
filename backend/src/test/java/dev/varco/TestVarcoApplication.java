// SPDX-License-Identifier: Apache-2.0
package dev.varco;

import org.springframework.boot.SpringApplication;

public class TestVarcoApplication {

    public static void main(String[] args) {
        SpringApplication.from(VarcoApplication::main)
                .with(TestcontainersConfiguration.class)
                .run(args);
    }
}
