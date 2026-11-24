package com.spendsheet.spendsheet

/**
 * Reads the amount, merchant and card from a Google Wallet notification.
 *
 * This is a copy of lib/features/wallet_capture/services/
 * wallet_notification_parser.dart, so the notification listener can tell a
 * payment apart while the app is closed. The Dart version stays the one
 * that fills in the inbox; change both together.
 */
object WalletPaymentParser {
    data class Payment(
        val amount: Double,
        /** The amount as Google Wallet wrote it, e.g. "$5.40" or "AED 45.00". */
        val amountText: String,
        val currency: String?,
        val merchant: String?,
        val cardLast4: String?,
    )

    // Dart's \s also covers Unicode spaces; Java's covers ASCII only.
    private const val WS = "[\\s\\u00A0\\u2007\\u2009\\u202F\\u3000\\uFEFF]"

    private const val SYMBOL = "(?:[A-Z]{1,3})?[\$€£¥₹₽₩₺₪₫฿₦₱₴₸₼₾\u20C3]"
    private const val CODE =
        "USD|EUR|GBP|INR|AED|SAR|QAR|KWD|BHD|OMR|JOD|EGP|CAD|AUD|NZD|SGD|HKD|" +
            "JPY|CNY|KRW|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|TRY|ILS|ZAR|NGN|KES|BRL|" +
            "MXN|ARS|CLP|COP|PEN|THB|MYR|IDR|PHP|VND|PKR|BDT|LKR|NPR|RUB|UAH"
    private const val NUMBER =
        "\\d{1,3}(?:[.,\\u00A0\\u202F’]\\d{3})+(?:[.,]\\d{1,2})?|\\d+(?:[.,]\\d{1,3})?"

    /** Currencies written with three decimals, where "1.500" is one and a half. */
    private val THREE_DECIMAL_CODES = setOf("KWD", "BHD", "OMR", "JOD", "TND")

    private val AMOUNT = Regex(
        "(?:(?<pre>$SYMBOL|\\b(?:$CODE))$WS?(?<n1>$NUMBER))" +
            "|(?:(?<n2>$NUMBER)$WS?(?<post>$SYMBOL|(?:$CODE)\\b))"
    )

    private val CARD = Regex("[•·∙●*]{2,}$WS?(\\d{4})\\b")

    private val NOT_A_PAYMENT = Regex(
        "\\b(declined|failed|unsuccessful|refund(ed)?|reversed|cancell?ed|" +
            "couldn['’]t|could not|cashback)\\b",
        RegexOption.IGNORE_CASE,
    )

    private val AFTER_AMOUNT = Regex(
        "^$WS*(?:paid$WS+)?(?:at|to|@)$WS+(.+)$",
        RegexOption.IGNORE_CASE,
    )

    private val BEFORE_AMOUNT = Regex(
        "^(?:you$WS+)?(?:paid|payment|sent)$WS+(?:to|at)$WS+(.+?)(?:$WS|[:,\\-–])*$",
        RegexOption.IGNORE_CASE,
    )

    private val CARD_PHRASE = Regex(
        "$WS*\\b(?:with|using|via|on)$WS+(?:your$WS+)?" +
            "(?:[^•·∙●*]{0,30}[•·∙●*]{2,}$WS?\\d{4}" +
            "|(?:visa|mastercard|amex|american express|discover|rupay|maestro|" +
            "debit|credit|card)\\b).*$",
        RegexOption.IGNORE_CASE,
    )

    private val GENERIC = Regex(
        "^(google$WS+(wallet|pay)|payment|purchase|transaction|paid|you paid|" +
            "payment (successful|complete|completed|made)|tap to pay|" +
            "contactless payment)(?:$WS|[.!:])*$",
        RegexOption.IGNORE_CASE,
    )

    private val LEADING_FILLER = Regex(
        "^(you$WS+)?(paid|payment|purchase)\\b(?:$WS|[:,\\-–])*(at|to)?$WS*",
        RegexOption.IGNORE_CASE,
    )
    private val SPACES = Regex("$WS+")
    private val EDGES = Regex("^(?:$WS|[:,\\-–•])+|(?:$WS|[:,\\-–•.])+$")
    private val LETTER = Regex("\\p{L}")
    private val DIRECTION_MARKS = Regex("[\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]")
    private val NUMBER_SPACES = Regex("[\\s\\u00A0\\u202F’]")

    /** Above this a number is a parsing accident, not a card payment. */
    private const val MAX_AMOUNT = 1e9

    fun parse(title: String, text: String): Payment? {
        val cleanTitle = clean(title)
        val cleanText = clean(text)
        val all = "$cleanTitle\n$cleanText"
        if (NOT_A_PAYMENT.containsMatchIn(all)) return null

        var titleMatch = AMOUNT.find(cleanTitle)
        val textMatch = AMOUNT.find(cleanText)
        // "AED 12.37 with Visa ••1234" in the text is the payment itself; an
        // amount-like piece of the title is then part of the merchant's name.
        if (titleMatch != null && textMatch != null && CARD_PHRASE.containsMatchIn(cleanText)) {
            titleMatch = null
        }
        val match = titleMatch ?: textMatch ?: return null

        val currency = match.groups["pre"]?.value ?: match.groups["post"]?.value
        val number = match.groups["n1"]?.value ?: match.groups["n2"]?.value ?: return null
        val amount = toDouble(number, threeDecimals = currency in THREE_DECIMAL_CODES)
        if (amount == null || !amount.isFinite() || amount <= 0 || amount > MAX_AMOUNT) {
            return null
        }

        val amountInTitle = titleMatch != null
        return Payment(
            amount = amount,
            amountText = match.value.trim(),
            currency = currency,
            merchant = merchant(
                withAmount = if (amountInTitle) cleanTitle else cleanText,
                other = if (amountInTitle) cleanText else cleanTitle,
                match = match,
            ),
            cardLast4 = CARD.find(all)?.groupValues?.get(1),
        )
    }

    private fun merchant(withAmount: String, other: String, match: MatchResult): String? {
        val after = AFTER_AMOUNT.find(withAmount.substring(match.range.last + 1))
        val before = BEFORE_AMOUNT.find(withAmount.substring(0, match.range.first))
        return tidy(after?.groupValues?.get(1))
            ?: tidy(before?.groupValues?.get(1))
            ?: tidy(other)
            ?: tidy(withAmount)
    }

    private fun tidy(value: String?): String? {
        if (value == null) return null
        var name = value
            .replace(CARD_PHRASE, "")
            .replace(AMOUNT, "")
            .replace(CARD, "")
            .replace(LEADING_FILLER, "")
            .replace(SPACES, " ")
            .replace(EDGES, "")
        if (name.isEmpty() || GENERIC.matches(name)) return null
        if (!LETTER.containsMatchIn(name)) return null
        if (name.length > 60) name = name.substring(0, 60).trimEnd()
        return name
    }

    private fun clean(value: String): String = value.replace(DIRECTION_MARKS, "").trim()

    /** Parses "1,234.56", "1.234,56", "5,40", "1 234,56" and "250". */
    private fun toDouble(raw: String, threeDecimals: Boolean): Double? {
        var s = raw.replace(NUMBER_SPACES, "")
        val lastComma = s.lastIndexOf(',')
        val lastDot = s.lastIndexOf('.')
        if (lastComma >= 0 && lastDot >= 0) {
            val decimal = if (lastComma > lastDot) "," else "."
            val group = if (decimal == ",") "." else ","
            s = s.replace(group, "").replace(decimal, ".")
        } else if (lastComma >= 0 || lastDot >= 0) {
            val sep = if (lastComma >= 0) "," else "."
            val digitsAfter = s.length - s.lastIndexOf(sep) - 1
            val isGrouping = digitsAfter == 3 && !threeDecimals
            s = if (isGrouping) s.replace(sep, "") else s.replace(sep, ".")
        }
        return s.toDoubleOrNull()
    }
}
