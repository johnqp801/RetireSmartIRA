//
//  TermsOfUseText.swift
//  RetireSmartIRA
//
//  Full Terms of Use text as a static string constant.
//  Update TermsAcceptanceManager.currentToUVersion when making material changes.
//

import Foundation

enum TermsOfUseText {

    private static var copyrightYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static var fullText: String {
        """
        TERMS OF USE
        RetireSmartIRA
        Alamo Ventures Group LLC

        Version \(TermsAcceptanceManager.currentToUVersion) — Effective Date: March 24, 2026

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        1. ACCEPTANCE OF TERMS

        By downloading, installing, or using RetireSmartIRA ("the App"), you agree to be bound by these Terms of Use ("Terms"). If you do not agree to these Terms, do not use the App.

        These Terms constitute a legally binding agreement between you and Alamo Ventures Group LLC ("we," "us," or "our"). Your continued use of the App signifies your acceptance of these Terms and any future amendments.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        2. NOT FINANCIAL, TAX, OR LEGAL ADVICE

        RetireSmartIRA is an educational planning tool that provides estimates, projections, and modeled scenarios based on user inputs and current tax law. Nothing in this App constitutes financial advice, tax advice, investment advice, or legal advice of any kind.

        All projections are hypothetical. The App does not recommend specific Roth conversion amounts, tax strategies, or financial actions. Terms like "optimal," "projected," or "modeled" describe mathematical estimates — they are not recommendations.

        You should consult a qualified tax professional, certified financial planner, or licensed advisor before making any financial decisions. Tax laws change frequently, and individual circumstances vary. We are not responsible for any decisions you make based on the App's output.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        3. ELIGIBILITY

        You must be at least 18 years of age to use this App. By using the App, you represent and warrant that you meet this age requirement.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        4. COST AND ACCESS

        RetireSmartIRA is currently provided free of charge. We reserve the right to introduce paid features or subscriptions in the future. If we do, we will update these Terms and notify you before any charges apply. You will not be charged without your explicit consent through the Apple App Store.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        5. INTELLECTUAL PROPERTY

        The App and all of its contents — including but not limited to source code, design, user interface, text, graphics, and calculation methodologies — are the intellectual property of Alamo Ventures Group LLC and are protected by copyright, trademark, and other applicable laws.

        You are granted a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes in accordance with these Terms.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        6. DISCLAIMER OF WARRANTIES

        THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

        We do not warrant that the App will be uninterrupted, error-free, or free of harmful components. We do not guarantee the accuracy of tax tables, IRMAA thresholds, RMD calculations, or any other data used by the App. Tax law changes may not be reflected immediately. You are responsible for verifying all calculations independently.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        7. LIMITATION OF LIABILITY

        TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, ALAMO VENTURES GROUP LLC SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE APP, INCLUDING BUT NOT LIMITED TO DAMAGES FROM RELIANCE ON PROJECTIONS, TAX PENALTIES, MISSED OPPORTUNITIES, OR FINANCIAL LOSSES.

        OUR TOTAL AGGREGATE LIABILITY FOR ALL CLAIMS ARISING FROM OR RELATED TO THE APP SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID TO US FOR THE APP IN THE 12 MONTHS PRECEDING THE CLAIM, OR (B) TEN DOLLARS ($10.00).

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        8. DISPUTE RESOLUTION AND ARBITRATION

        8.1 Informal Resolution
        Before initiating any formal dispute resolution, you agree to contact us at retiresmartira@gmail.com and attempt to resolve the dispute informally for at least 30 days.

        8.2 Binding Arbitration
        If informal resolution fails, any dispute arising from or relating to these Terms or the App shall be resolved by binding arbitration administered by JAMS in Contra Costa County, California. The arbitration shall be conducted by a single arbitrator in accordance with the JAMS Streamlined Arbitration Rules and Procedures.

        8.3 Class Action Waiver
        YOU AGREE THAT ANY DISPUTE RESOLUTION PROCEEDINGS WILL BE CONDUCTED ONLY ON AN INDIVIDUAL BASIS AND NOT IN A CLASS, CONSOLIDATED, OR REPRESENTATIVE ACTION. You waive any right to participate in a class action lawsuit or class-wide arbitration.

        8.4 Exception
        Notwithstanding the above, either party may seek injunctive or other equitable relief in any court of competent jurisdiction to prevent the actual or threatened infringement of intellectual property rights.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        9. PRIVACY AND CCPA

        We respect your privacy. The App performs all calculations locally on your device. We do not sell your personal information.

        If you are a California resident, you have rights under the California Consumer Privacy Act (CCPA), including the right to know what personal information is collected, the right to request deletion, and the right to opt out of the sale of personal information. We do not sell personal information.

        For privacy inquiries or to exercise your CCPA rights, contact us at retiresmartira@gmail.com. See our Privacy Policy for full details.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        10. GOVERNING LAW

        These Terms shall be governed by and construed in accordance with the laws of the State of California, without regard to conflict of law provisions.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        11. CHANGES TO THESE TERMS

        We may update these Terms from time to time. When we make material changes, we will update the version number and the App will prompt you to review and accept the updated Terms before continuing. Your acceptance of updated Terms is required to continue using the App.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        12. CONTACT

        Alamo Ventures Group LLC
        Alamo, California

        retiresmartira@gmail.com

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        \u{00A9} \(copyrightYear) Alamo Ventures Group LLC. All rights reserved.
        """
    }

    // MARK: - Privacy Policy

    static var privacyPolicy: String {
        """
        PRIVACY POLICY
        RetireSmart IRA
        Alamo Ventures Group LLC

        Last updated: March 5, 2026

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        RetireSmart IRA is designed with your privacy as a core principle. All of your personal and financial data stays on your device. We do not collect, transmit, or store any of your information on external servers.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        INFORMATION YOU ENTER

        To provide retirement tax planning estimates, the app asks you to enter information such as:

        • Date of birth and spouse information
        • Filing status and state of residence
        • IRA and retirement account balances
        • Income sources and amounts
        • Deduction details
        • Tax planning scenario inputs (Roth conversions, QCDs, withdrawals)

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        HOW YOUR DATA IS STORED

        All data you enter is stored locally on your device only, using the operating system's standard on-device storage. Your data is:

        • Never transmitted to any server, cloud service, or third party
        • Never synced to iCloud or any cloud storage
        • Never shared with advertisers, analytics providers, or data brokers
        • Never accessible to the app developer

        If you delete the app, all locally stored data is permanently removed.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        NO DATA COLLECTION

        RetireSmart IRA does not collect:

        • Personal identifiers or contact information
        • Usage or analytics data
        • Location data
        • Device identifiers or fingerprints
        • Browsing or search history
        • Advertising data

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        NO THIRD-PARTY SDKs

        The app contains no third-party analytics, advertising, or tracking frameworks. The app does not communicate with any external servers. All calculations are performed entirely on your device.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        CHILDREN'S PRIVACY

        This app is not directed at children under 13. It is a financial planning tool intended for adults planning for retirement.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        CHANGES TO THIS POLICY

        If this privacy policy is updated, the revised version will be posted at www.retiresmartira.com and within the app, with an updated date. Continued use of the app after changes constitutes acceptance of the revised policy.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        CONTACT

        If you have questions about this privacy policy, you can contact us at:

        retiresmartira@gmail.com

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        \u{00A9} \(copyrightYear) Alamo Ventures Group LLC. All rights reserved.
        """
    }
}
