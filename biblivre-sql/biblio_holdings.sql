COPY (
    SELECT biblio_holdings.id, biblio_holdings.record_id, biblio_holdings.iso2709, biblio_holdings.database, biblio_holdings.accession_number, location_d, biblio_holdings.created, biblio_holdings.created_by, biblio_holdings.modified, biblio_holdings.modified_by, biblio_holdings.material, biblio_holdings.availability, biblio_holdings.label_printed
    FROM single.biblio_holdings
) TO STDOUT WITH CSV HEADER;
