SELECT
    fd.deal_id AS "Deal ID",
    fd.deal_name AS "Deal Name",
    da.account_name AS "Account Name",
    dr.rep_name AS "Rep Name",
    fd.amount AS "Amount",
    ds.stage_name AS "Stage",
    'Open' AS "Status",
    '' AS "Notes"
FROM fact_deals fd
JOIN dim_accounts da ON fd.account_id = da.account_id
JOIN dim_reps dr ON fd.rep_id = dr.rep_id
JOIN dim_stages ds ON fd.stage_id = ds.stage_id
WHERE fd.status = 'Open'
LIMIT 15;