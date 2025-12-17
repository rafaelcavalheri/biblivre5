COPY (
    SELECT lendings.id, lendings.user_id, users.name, lendings.holding_id, lendings.return_date, lendings.created, lendings.expected_return_date
    FROM single.lendings
    INNER JOIN single.users ON lendings.user_id = users.id
) TO STDOUT WITH CSV HEADER;
