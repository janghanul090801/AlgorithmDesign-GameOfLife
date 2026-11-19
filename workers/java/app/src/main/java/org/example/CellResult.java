package org.example;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor 
public class CellResult {
    @JsonProperty("type")
    private String resultType;
    @JsonProperty("job_id")
    private Long jobId;
    private Long generation;
    private Integer x;
    private Integer y;
    private Boolean alive;
}
