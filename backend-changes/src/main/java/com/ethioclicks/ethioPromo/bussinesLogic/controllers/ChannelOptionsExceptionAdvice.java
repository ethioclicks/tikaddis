package com.ethioclicks.ethioPromo.bussinesLogic.controllers;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import java.util.Map;

// Preserve meaningful 400/404/409 responses before the existing generic advice.
@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
public class ChannelOptionsExceptionAdvice {
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> handle(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatusCode())
                .body(Map.of("message", error.getReason() == null ? "Request failed." : error.getReason()));
    }
}
