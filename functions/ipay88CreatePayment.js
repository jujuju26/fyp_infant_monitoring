const functions = require("firebase-functions");
const crypto = require("crypto");

exports.createIpay88Payment = functions.https.onRequest((req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        return res.status(200).end();
    }

    const {
        amount,
        refNo,
        userName,
        userEmail,
        userContact,
        description,
    } = req.body;

    const merchantCode = "M27520";
    const merchantKey = "zdurUt8zIL";

    // Convert amount to cents, e.g. 1.00 -> 100
    const amountNumber = parseFloat(amount);
    const formattedAmount = (amountNumber * 100).toFixed(0);

    const rawSignature = merchantKey + merchantCode + refNo + formattedAmount + "MYR";
    const sha1 = crypto.createHash("sha1").update(rawSignature).digest();
    const signature = Buffer.from(sha1).toString("base64");

    const redirectForm = `
        <html>
        <body onload="document.forms[0].submit()">
            <form method="post" action="https://sandbox.ipay88.com.my/epayment/entry.asp">
                <input type="hidden" name="MerchantCode" value="${merchantCode}" />
                <input type="hidden" name="PaymentId" value="" />
                <input type="hidden" name="RefNo" value="${refNo}" />
                <input type="hidden" name="Amount" value="${formattedAmount}" />
                <input type="hidden" name="Currency" value="MYR" />
                <input type="hidden" name="ProdDesc" value="${description}" />
                <input type="hidden" name="UserName" value="${userName}" />
                <input type="hidden" name="UserEmail" value="${userEmail}" />
                <input type="hidden" name="UserContact" value="${userContact}" />
                <input type="hidden" name="Signature" value="${signature}" />
                <input type="hidden" name="ResponseURL" value="https://lullacare.web.app/payment-success" />
                <input type="hidden" name="BackendURL" value="https://us-central1-lullacare.cloudfunctions.net/api/ipay88Response" />
            </form>
        </body>
        </html>
    `;

    res.status(200).send(redirectForm);
});
