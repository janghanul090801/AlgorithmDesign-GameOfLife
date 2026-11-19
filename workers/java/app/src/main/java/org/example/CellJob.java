package org.example;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;

@Getter
public class CellJob {
    @JsonProperty("type")
    private String jobType;
    private Long id;
    private Long generation;
    private Integer x;
    private Integer y;
    private Boolean current;
    private Board board;
}
