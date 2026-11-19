package org.example;

import java.util.List;
import lombok.Getter;

@Getter
public class Board {
    private Integer width;
    private Integer height;
    private List<List<Boolean>> cells;
}
