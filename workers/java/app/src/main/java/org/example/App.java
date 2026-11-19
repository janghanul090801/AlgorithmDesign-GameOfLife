package org.example;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;

import com.fasterxml.jackson.databind.ObjectMapper;

public class App {
    public Integer countNeighbors(Board board, int x, int y) {
        int count = 0;
        for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) 
                    continue;
            
                int nx = x + dx;
                int ny = y + dy;

                if (nx < 0 || ny < 0 || nx >= board.getWidth() || ny >= board.getHeight())
                    continue;

                if (board.getCells().get(ny).get(nx))
                    count += 1;
            }
        return count;
    }

    public Boolean calculate(boolean current, int neighbors) {
        if (current && (neighbors == 2 || neighbors == 3))
		    return true;

        if (!current && neighbors == 3)
            return true;
        

        return false;
    }

    public static void main(String[] args) throws IOException {
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(System.out));
        ObjectMapper mapper = new ObjectMapper();
        App app = new App();
        String line;
        while ((line = reader.readLine()) != null) {
            if (line.trim().isEmpty())
                continue;

            CellJob cellJob;
            try {
                cellJob = mapper.readValue(line, CellJob.class);
            } catch (IOException e) {
                System.err.println("failed to decode job: " + e.getMessage());
                continue;
            }

            if (!"cell".equals(cellJob.getJobType()))
                continue;

            boolean alive = app.calculate(cellJob.getCurrent(), app.countNeighbors(cellJob.getBoard(), cellJob.getX(), cellJob.getY()));

            CellResult result = new CellResult("result", cellJob.getId(), cellJob.getGeneration(), cellJob.getX(), cellJob.getY(), alive);
            String jsonResult = mapper.writeValueAsString(result);

            writer.write(jsonResult);
            writer.newLine();
            writer.flush();
        }
    }
}
