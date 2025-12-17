COPY (
    SELECT lending_fines.id, lending_fines.lending_id, lending_fines.user_id, lending_fines.fine_value, lending_fines.payment_date, lending_fines.created, lending_fines.created_by
    FROM single.lending_fines
) TO STDOUT WITH CSV HEADER;
