using System;
using Tessa.Cards;
using Tessa.Extensions.Shared.Info;
using Tessa.Localization;
using Tessa.Platform.Runtime;
using Tessa.Platform.Storage;
using Tessa.UI;
using Tessa.UI.Cards;
using Tessa.UI.Cards.Controls.AutoComplete;

namespace Tessa.Extensions.Client.UI
{
	public sealed class AuthorUIExtension : CardUIExtension
	{
		#region Fields

		private readonly ISession session;
		private readonly ICardRepository cardRepository;

		#endregion

		#region Constructors

		public AuthorUIExtension(ISession session, ICardRepository cardRepository)
		{
			this.session = session;
			this.cardRepository = cardRepository;
		}

		#endregion

		#region Base Overrides

		public override void Initialized(ICardUIExtensionContext context)
		{
			ICardModel model;
			Card card;
			StringDictionaryStorage<CardSection> sections;

			if ((model = context.Model) == null
				|| model.InSpecialMode()
				|| (card = model.Card) == null
				|| (sections = card.TryGetSections()) == null
				|| !sections.TryGetValue(SchemeInfo.DocumentCommonInfo, out CardSection dciSection))
			{
				return;
			}

			// Получаем контрол исполнителя
			if (!model.Controls.TryGet(SchemeInfo.DocumentCommonInfo.AuthorID, out IControlViewModel control))
			{
				return;
			}

			// При изменении исполнителя производим корректировку подразделения
			((AutoCompleteEntryViewModel)control).ValueSelected += (s, e) =>
			{
				Guid newUserID = (Guid)e.Item.Reference;

				var request = new CardRequest { RequestType = RequestTypes.GetUserFullInfoRequest };
				request.Info.Add(InfoMarks.UserID, newUserID);

				CardResponse response = cardRepository.Request(request);

				if (response.Info != null)
				{
					var depID = response.Info.TryGet<Guid?>(InfoMarks.DepID);
					var depName = response.Info.TryGet<string>(InfoMarks.DepName);
					var depIndex = response.Info.TryGet<string>(InfoMarks.DepIndex);

					if (depID != null)
					{
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentID))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentID] = depID;
						}
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentName))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentName] = depName;
						}
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentIndex))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentIndex] = depIndex;
						}
					}
					else
					{
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentID))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentID] = null;
						}
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentName))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentName] = null;
						}
						if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentIndex))
						{
							dciSection.Fields[SchemeInfo.DocumentCommonInfo.DepartmentIndex] = null;
						}

						TessaDialog.ShowError(LocalizationManager.GetString("General_Validation_No_Info_About_Employee"));
					}
				}
			};
		}

		public override void Saving(ICardUIExtensionContext context)
		{
			ICardModel model;
			Card cardSave;
			StringDictionaryStorage<CardSection> sections;

			if ((model = context.Model) == null
				|| model.InSpecialMode()
				|| (cardSave = context.Card) == null
				|| (sections = cardSave.TryGetSections()) == null
				|| !sections.TryGetValue(SchemeInfo.DocumentCommonInfo, out CardSection dciSection))
			{
				return;
			}

			if (dciSection.Fields.ContainsKey(SchemeInfo.DocumentCommonInfo.DepartmentID))
			{
				Guid? departmentID = dciSection.Fields.TryGet<Guid?>(SchemeInfo.DocumentCommonInfo.DepartmentID);

				if (!departmentID.HasValue)
				{
					TessaDialog.ShowMessage("$General_Validation_No_Info_About_Employee", "$General_CaptionDialog_Save");
					context.Cancel = true;
					return;
				}
			}
		}

		#endregion
	}
}
