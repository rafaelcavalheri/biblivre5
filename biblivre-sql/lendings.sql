COPY (
    SELECT lendings.id, lendings.holding_id, lendings.user_id, lendings.previous_lending_id, lendings.expected_return_date, lendings.return_date, lendings.created, lendings.created_by
    FROM single.lendings
) TO STDOUT WITH CSV HEADER;
